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

Date toDate(string sqlDate)
{
  Date t;
  return t.fromISOExtString(sqlDate);
}

string toSqlDate(Date date)
{
  return date.toISOExtString();
}

DateTime toDateTime(string sqlTime)
{
  DateTime t;
  return t.fromISOExtString(sqlTime.replaceFirst(" ", "T"));
}

SysTime toSysTime(string sqlTime, immutable TimeZone tz = null)
{
  return SysTime(toDateTime(sqlTime),tz);
}

string toSqlTime(DateTime time)
{
  return time.toISOExtString().replaceFirst("T", " ");
}

string toSqlTime(SysTime time, immutable TimeZone tz = null)
{
  if (tz is null)
    return time.toLocalTime().toISOExtString().replaceFirst("T", " ");
  else
    return time.toOtherTZ(tz).toISOExtString().replaceFirst("T", " ");
}
