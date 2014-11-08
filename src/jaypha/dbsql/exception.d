//Written in the D programming language
/*
 * Database exception class.
 *
 * Copyright (C) 2009-2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.dbms.exception;

import std.conv;

class DBException : Exception
{
 	this () { super("Unknown Error.");	}

	this (string msg, uint _code, string _sql)
  {
		super(msg~" ("~to!string(_code)~"), SQL: \""~_sql~"\"");
    code = _code;
    sql = _sql;
  }

  uint code;
  string sql;
}
