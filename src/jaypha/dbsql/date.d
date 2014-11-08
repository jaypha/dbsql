//Written in the D programming language
/*
 * Convert between SQL time format and D time structures.
 *
 * Copyright (C) 2014 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */


module jaypha.dbsql.date;

import std.datetime;
import std.array;

/*
 * If the database is using a different timezone than the system, you will
 * need to supply its timezone, otherwise you can use the defaults.
 */


DateTime toDateTime(string sqlTime)
{
  DateTime t;
  return t.fromISOExtString(mysqlTime.replaceFirst(" ", "T"));
}

SysTime toSysTime(string sqlTime, immutable TimeZone tz = null)
{
  return SysTime(toDateTime(mysqlTime),tz);
}

string toSqlTime(DateTime time)
{
  return time.toISOExtString().replaceFirst("T", " ");
}

string toSqlTime(SysTime time, immutable TimeZone tz)
{
  if (tz is null)
    return time.toLocalTime().toISOExtString().replaceFirst("T", " ");
  else
    return time.toOtherTZ(tz).toISOExtString().replaceFirst("T", " ");
}