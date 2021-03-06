//Written in the D programming language
/*
 * MySQL database connection tool
 *
 * Copyright 2009-2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.dbsql.mysql.database;

import jaypha.dbsql.mysql.c.mysql;
import jaypha.dbsql.exception;
import jaypha.algorithm;

import std.conv;
import std.string;
import std.array;
import std.algorithm;


//-----------------------------------------------------------------------------
//
// Database
//
//-----------------------------------------------------------------------------

final class MySqlDatabase
{
  alias MySQLRange ResultType;

  string host;
  string dbname;
  string username;
  string password = null;
  uint port = 0;

  //---------------------------------------------------------------------------

  ~this() { close(); }

  //---------------------------------------------------------------------------

  void connect()
  {
    if (mysql is null)
    {
      mysql = mysql_init(mysql);
      if
      (
        mysql_real_connect
        (
          mysql,
          toStringz(host),
          toStringz(username),
          toStringz(password),
          toStringz(dbname),
          port,
          null,
          0
        ) is null
      )
      {
        throw new DBException(to!string(mysql_error(mysql)), mysql_errno(mysql), null);
      }
    }
  }

  //---------------------------------------------------------------------------

  void close()
  {
    if (mysql !is null)
    {
      mysql_close(mysql);
      mysql = null;
    }
  }

  //---------------------------------------------------------------------------

  string quote(string s)
  {
		if (s == "") { return "''"; }
    if (s is null) { return "null"; }

		char[] result;
		result.length = s.length * 2+1;

    if (mysql is null) connect();
		// string doesn't need to be 0-term
    result.length = mysql_real_escape_string
    (
      mysql,
      result.ptr,
      s.ptr,
      s.length
    );

    if (mysql_errno(mysql) != 0)
      throw new DBException(to!string(mysql_error(mysql)), mysql_errno(mysql), s);

		return "'"~result.idup~"'";
  }

  //---------------------------------------------------------------------------

  string inList(T)(T[] list)
  {
    if (list.empty) return ("0");
    static if (is(T == string))
      return "("~map!(a => quote(a))(list).join(",")~")";
    else
      return "("~map!(to!string)(list).join(",")~")";
  }

  //---------------------------------------------------------------------------
  // General query function. Can be used with both retrieval and modification.
  //---------------------------------------------------------------------------

  ResultType query(string sql)
  {

    MYSQL_RES* res = query_raw(sql);

    return ResultType(res);
  }

  //---------------------------------------------------------------------------
  // Retireval functions
  //---------------------------------------------------------------------------

  string queryValue(string sql)
  {
    MYSQL_RES* res = query_raw(sql);
    scope(exit) { mysql_free_result(res); }
    string result;
    
    if (!get_single(res, result))
      return null;
    
    while (mysql_fetch_row(res) !is null) {}
    return result;
  }

  //---------------------------------------------------------------------------

  string[string] queryRow(string sql)
  {
    MYSQL_RES* res = query_raw(sql);
    scope(exit) { mysql_free_result(res); }
    string[string] result = get_row(res);
    
    while (mysql_fetch_row(res) !is null) {}
    return result;
  }

  //---------------------------------------------------------------------------

  string[string][] queryData(string sql)
  {
    MYSQL_RES* res = query_raw(sql);
    scope(exit) { mysql_free_result(res); }

    auto data = appender!(string[string][])();
    //string[string][] data;
    string[string] row;
    
    while ((row = get_row(res)) !is null)
      data.put(row);
    return data.data;
  }

  //---------------------------------------------------------------------------

  T[] queryColumn(T = string)(string sql)
  {
    MYSQL_RES* res = query_raw(sql);
    scope(exit) { mysql_free_result(res); }

    auto data = appender!(T[])();
    //string[] data;
    string v;
    
    while (get_single(res,v))
      data.put(to!T(v));
    return data.data;
  }

  //---------------------------------------------------------------------------

  //
  // constraints
  // first column is used as the index.
  // first column must be unique, and of the correct type.
  //

  string[string][T] queryIndexedData(T = string)(string sql)
  {
    MYSQL_RES* res = query_raw(sql);
    scope(exit) { mysql_free_result(res); }
    
    bool ok = false;
    int numFields = mysql_num_fields(res);
    MYSQL_FIELD* fields = mysql_fetch_fields(res);
    auto idColumn = to!string(fields[0].name);

    // TODO test type of id_column
    
    string[string][T] data;

    string[string] row;
    
    while ((row = get_row(res)) !is null)
      data[to!(T)(row[idColumn])] = row;
    return data;
  }

  //---------------------------------------------------------------------------

  //
  // constraints
  // first column is used as the index.
  // first column must be unique, and of the correct type.
  //

  U[T] queryIndexedColumn(T = string,U = string)(string sql)
  {
    MYSQL_RES* res = query_raw(sql);
    scope(exit) { mysql_free_result(res); }

    U[T] data;

    if (mysql_num_fields(res) != 2)
      throw new DBException
      (
        "query_indexed_column must be called with a query that returns "
        "two columns",0, sql
      );

    // TODO test type of id_column

    MYSQL_ROW row;

    while ((row = mysql_fetch_row(res)) !is null)
    {
      ulong* lengths = mysql_fetch_lengths(res);

      data[to!(T)(row[0][0..lengths[0]])] = to!U(row[1][0..lengths[1]]);
    }

    return data;
  }

  //---------------------------------------------------------------------------
  // Database write methods
  //---------------------------------------------------------------------------

  //
  // constraints
  // values are expected to be already vetted. Functions will enquote.
  //

  @property string insertId() { return to!string(mysql_insert_id(mysql)); }
  string getInsertId() { return insertId; }

  //---------------------------------------------------------------------------
  // Insert a single row. Names and values are given as an AA. Return the ID
  // for the row

  string insert(string tablename, string[string] values)
  {
    return insert(tablename, values.keys, values.values);
  }

  //---------------------------------------------------------------------------
  // Insert a single row. Names and values are given separately. Return the ID
  // for the row

  string insert(string tablename, string[] columns, string[] values)
  {
    query_raw
    (
      "insert into `"~tablename~"` (`" ~
      columns.join("`,`") ~
      "`) values (" ~
      values.map!((a) => quote(a)).join(",") ~
      ")"
    );
    return getInsertId();
  }

  //---------------------------------------------------------------------------
  // Insert a number of rows.

  void insert(string tablename, string[] columns, string[][] values)
  {
    auto str = appender!string();

    str.put("insert into `");
    str.put(tablename);
    str.put("` (");
    str.put(columns.join(","));
    str.put(") values (");
    //... TODO may be flakey.

    string[] vSql;
    foreach (v;values)
      vSql ~= v.map!((a) => quote(a)).join(",");
    str.put(vSql.join("),("));
    str.put(")");
    query(str.data);
  }


  //---------------------------------------------------------------------------

  void update(string tablename, string[string] values, string where)
  {
    update(tablename, values, [ where ]);
  }

  //---------------------------------------------------------------------------

  void update(string tablename, string[string] values, string[] wheres)
  {
    query_raw
    (
      "update `"~tablename~"` set "~
      meld!
      (
        (a,b) => (a~"="~quote(b))
      )
      (values).join(",")~" where "~wheres.join(" and ")
    );
  }

  //---------------------------------------------------------------------------

  void update(string tablename, string[] columns, string[] values, string where)
  {
    update(tablename, columns, values, [ where ]);
  }

  //---------------------------------------------------------------------------

  void update(string tablename, string[] columns, string[] values, string[] wheres)
  {
    string[] s;

    for (int i=0; i<columns.length; ++i)
      s~= columns[i] ~ "=" ~ quote(values[i]);

    
    query_raw("update `"~tablename~"` set "~join(s,",")~" where "~wheres.join(" and "));
  }

  //---------------------------------------------------------------------------

  void replace(string tablename, string[string] values)
  {
    query_raw
    (
      "replace into  `"~tablename~"` set "~
      meld!
      (
        (a,b) => (a~"="~quote(b))
      )
      (values).join(",")
    );
  }

  //---------------------------------------------------------------------------
  // CRUD Shortcuts for use with ids
  //---------------------------------------------------------------------------
  // Assumes the table has a column `id` of type unigned integer (or long)
  // and has a unique value index. We use strings to reduce the back-and-forth
  // conversion between string and ulong that occurs in websites.
  //---------------------------------------------------------------------------

  alias insert create;

  //---------------------------------------------------------------------------

  string[string] get(string table, string id)
  {
    return queryRow("select * from `"~table~"` where id="~id);
  }

  //---------------------------------------------------------------------------

  // If you want to insert a row with a non-empty id, use 'insert'.

  string set(string tablename, string[string] values, string id = null)
  {
    if (id is null)
      return insert(tablename, values);
    else
    {
      update(tablename, values, [ "id="~id ]);
      return id;
    }
  }

  //---------------------------------------------------------------------------

  void remove(string tablename, string id)
  {
    query("delete from `"~tablename~"` where id="~id);
  }

  void remove(string tablename, string[] ids)
  {
    if (ids.empty)
      return;
    else
      query("delete from `"~tablename~"` where id in "~inList(ids));
  }

  //---------------------------------------------------------------------------
  // Database reflection methods
  //---------------------------------------------------------------------------

  bool tableExists(string tablename)
  {
    return (queryValue("show tables like "~quote(tablename)) !is null);
  }
  
  //---------------------------------------------------------------------------

  string[] getTables()
  {
    return queryColumn("show tables");
  }
  
  //---------------------------------------------------------------------------

  bool isConnected() { return mysql !is null; }

  //---------------------------------------------------------------------------

  // The following allow direct access, use with caution
  
  MYSQL* get_handle() { return mysql; }

  MYSQL_RES* query_raw(string sql)
  {
    if (mysql is null) connect();
    
    if (mysql_real_query(mysql, sql.ptr, sql.length) != 0)
      throw new DBException(to!string(mysql_error(mysql)), mysql_errno(mysql), sql);
    
    MYSQL_RES* res = mysql_use_result(mysql);
    if (mysql_errno(mysql) != 0)
      throw new DBException(to!string(mysql_error(mysql)), mysql_errno(mysql), sql);

    return res;
  }

  struct MySQLRange
  {
    this(MYSQL_RES* r)
    {
      res = r;

      if (r !is null)
        popFront();
    }
    @property bool empty() { return row is null; }
    @property string[string] front() { return row; }

    void popFront()
    {
      row = get_row(res);
      if (row is null)
      {
        mysql_free_result(res);
        res = null;
      }
    }

    private:
      MYSQL_RES* res;
      string[string] row = null;
  }

  void cancel(ref ResultType r)
  {
    mysql_free_result(r.res);
  }

  private:

    MYSQL* mysql = null;

    int error_code;

    //-------------------------------------------------------------------------
}

package:


bool get_single(MYSQL_RES* res, ref string v)
{
  MYSQL_ROW row = mysql_fetch_row(res);
  if (row is null)
  {
    if (mysql_errno(res.handle) != 0)
      throw new DBException(to!string(mysql_error(res.handle)), mysql_errno(res.handle),"");
    else
      return false;
  }
  auto lengths = mysql_fetch_lengths(res);
  if (row[0] is null)
    v = null;
  else
    v = row[0][0..lengths[0]].idup;
  return true;
}

//-------------------------------------------------------------------------

string[string] get_row(MYSQL_RES* res)
{
  string[string] r;


  MYSQL_ROW row = mysql_fetch_row(res);

  if (row is null)
  {
    if (mysql_errno(res.handle) != 0)
      throw new DBException(to!string(mysql_error(res.handle)), mysql_errno(res.handle),"");
    else
      return null;
  }

  uint numFields = mysql_num_fields(res);

  MYSQL_FIELD* fields = mysql_fetch_fields(res);

  auto lengths = mysql_fetch_lengths(res);

  for (int i = 0; i < numFields; ++i)
  {
    auto s = fields[i].name[0..fields[i].name_length].idup;

    if (row[i] is null)
      r[s] = null;
    else
      r[s] = row[i][0..lengths[i]].idup;
  }
  return r;
}
