//Written in the D programming language
/*
 * Construct a MySQL query.
 *
 * Copyright (C) 2014 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */


module jaypha.dbsql.mysql.dynamicquery;

import std.array;
import std.algorithm;
import std.conv;
import std.string;
import jaypha.dbsql.mysql.database;

struct MySqlDynamicQuery
{
  MySqlDatabase db;

  //-------------------------------------------------------------------------

  enum JoinType:string { Left = "left", Right = "right", Inner = "inner" };

  struct Table
  {
    string name;
    JoinType join;
    string condition;
  }

  enum SortType:string { Asc = "asc", Desc = "desc" };

  struct SortClause
  {
    string column;
    SortType dir;
  }

  //-------------------------------------------------------------------------

  string table = null;

  bool distinct = true;

  string[] columns = [];
  string[] wheres = [];
  SortClause[] sorting = [];

  SortClause[] groups = [];
  string[] havings = [];

  string query = null;

  ulong limit = ulong.max;

  //-------------------------------------------------------------------------

  void addTable(string name, JoinType join = JoinType.Inner, string condition=null)
  {
    tables~= Table(name, join, condition);
  }

  //-------------------------------------------------------------------------

  void addSorting(string name, SortType dir = SortType.Asc)
  {
    sorting ~= SortClause(name, dir);
  }

  //-------------------------------------------------------------------------

  void addGrouping(string name, SortType dir = SortType.Asc)
  {
    sorting ~= SortClause(name, dir);
  }

  //-------------------------------------------------------------------------
  // Retrieval  methods
  //-------------------------------------------------------------------------

  string getCountQuery()
  {
    return "select count(*) from ("~sql()~") as tmp";
  }

  //-----------------------------------
  // Get the SQL.

  string sql(ulong start = 0, ulong limit = ulong.max)
  in
  {
    assert (table !is null || query !is null);
  }
  body
  {
    if (this.limit < limit) limit = this.limit;
    if (query !is null)
    {
      return query ~ getLimitSql(start,limit);
    }

    auto sql = appender!string();

    sql.put("select ");
    sql.put(getColumnsSql());
    sql.put(" from ");
    sql.put(getTablesSql());
    sql.put(getWheresSql());
    sql.put(getGroupingSql());
    sql.put(getHavingSql());
    sql.put(getSortingSql());
    sql.put(getLimitSql(start,limit));

    return sql.data;
  }

  //------------------------------------------------------

  @property ulong length()
  {
    return to!ulong(db.queryValue(getCountQuery()));
  }

  @property ulong numPages(ulong start = 0, ulong limit = ulong.max)
  {
    auto count = length;
    if (limit == ulong.max)
      return count;
    else
      return (count + limit - 1)/limit;
  }

  //------------------------------------------------------

  auto apply(ulong start = 0, ulong limit = ulong.max)
  {
    return db.query(sql(start,limit));
  }

  auto opSlice()
  {
    return db.query(sql());
  }

  auto opSlice(size_t pos = 0)(ulong s, ulong f)
  {
    static assert(pos == 0);
    if (f == ulong.max)
      return db.query(sql(s));
    else
      return db.query(sql(s, f-s));
  }

  ulong opDollar(size_t pos = 0)()
  {
    static assert(pos == 0);
    return ulong.max;
  }

  //------------------------------------------------------

  private:

  string getColumnsSql()
  {
    if (columns.length == 0)
      return "*";

    return "distinct " ~ join(columns,",");
  }

  //------------------------------------------------------

  string getTablesSql()
  {
    auto sql = appender!string();

    sql.put(table);
    foreach (t; tables)
    {
      sql.put(" ");
      sql.put(cast(string)t.join);
      sql.put(" join ");
      sql.put(t.name);
      if (t.condition)
      {
        if (indexOf(t.condition, '=') < 0)
          sql.put(" using (");
        else
          sql.put(" on (");
        sql.put(t.condition);
        sql.put(")");
      }
    }
    return sql.data;
  }

  //------------------------------------------------------

  string getWheresSql()
  {
    if (wheres.length == 0)
      return "";

    return " where (" ~ join(wheres,") and (") ~ ")";
  }

  //------------------------------------------------------

  string getSortingSql()
  {
    if (sorting.length == 0)
      return "";

    auto sql = appender!string();
    sql.put(" order by ");

    sql.put
    (
      join
      (
        map!(a => a.column ~ " " ~ a.dir)(sorting),
        ","
      )
    );

    return sql.data;
  }

  //------------------------------------------------------

  string getGroupingSql()
  {
    if (groups.length == 0)
      return "";

    auto sql = appender!string();
    sql.put(" group by ");

    sql.put
    (
      join
      (
        map!(a => a.column ~ " " ~ a.dir)(groups),
        ","
      )
    );

    return sql.data;
  }

  //------------------------------------------------------

  string getHavingSql()
  {
    if (havings.length == 0)
      return "";

    return " having (" ~ join(havings,") and (") ~ ")";
  }

  //------------------------------------------------------

  string getLimitSql(ulong start, ulong limit)
  {
    if (limit == ulong.max && start == 0) return "";

    auto sql = " limit "~to!string(limit);
    if (start != 0)
      sql ~= " offset "~to!string(start);
    return sql;
  }

  //------------------------------------------------------

  Table[] tables;
}

//----------------------------------------------------------------------------


//----------------------------------------------------------------------------

  import jaypha.datasource;

unittest
{
  import std.stdio;

  static assert(isDataSource!MySqlDynamicQuery);
  static assert(is(DataSourceElementType!MySqlDynamicQuery == string[string]));

  MySqlDynamicQuery dq;

  dq.table = "members";
  dq.addTable("ww", MySqlDynamicQuery.JoinType.Left, "members.x = ww.y");
  dq.addTable("zz");
  dq.wheres ~= "x = 1";
  dq.havings ~= "y = 4";
  dq.addGrouping("zz.g");
  dq.addSorting("y");
  dq.addSorting("z",MySqlDynamicQuery.SortType.Desc);

  assert(dq.sql() == "select * from members left join ww on (members.x = ww.y) inner join zz where (x = 1) having (y = 4) order by zz.g asc,y asc,z desc");
  assert(dq.sql(6,7) == "select * from members left join ww on (members.x = ww.y) inner join zz where (x = 1) having (y = 4) order by zz.g asc,y asc,z desc limit 7 offset 6");

  dq.query = "select rt from by";
  assert(dq.sql() == "select rt from by");
  assert(dq.sql(10,5) == "select rt from by limit 5 offset 10");
}
