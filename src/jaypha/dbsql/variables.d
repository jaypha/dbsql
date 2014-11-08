//Written in the D programming language
/*
 * Persistant storage for singular variables.
 *
 * Copyright (C) 2013-2014 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.dbms.variables;

import jaypha.types;
import jaypha.io.serialize;


struct Variables(Database)
{
  Database database;
  string table;

  private strstr values;

  bool isSet(string name)
  {
    if (name in values)
      return true;
    else
      return (database.queryValue("select count(*) from "~table~" where name='"~name~"'") != "0");
  }

  string get(T:string)(string name)
  {
    if (!(name in values))
    {
      auto s = database.queryValue("select value from "~table~" where name='"~name~"'");
      if (s is null)
        return null;
      else
      {
        values[name] = s;
      }
    }
    return values[name];
  }

  T get(T)(string name)
  {
    auto s = get!string(name);
    return (s is null)?T.init:unserialize!T(s);
  }

  void set(T:string)(string name, string value)
  {
    values[name] = value;
    database.query("replace "~table~" set name='"~name~"', value="~database.quote(value));
  }

  void set(T)(string name, T value)
  {
    set!string(name,serialize!(T)(value));
  }

  void unset(string name)
  {
    database.query("delete from "~table~" where name='"~name~"'");
    values.remove(name);
  }

  alias set!ulong  setInt;
  alias set!string setStr;

  alias get!ulong  getInt;
  alias get!string getStr;
}
