#!/usr/bin/ruby

# slit 1.0  Copyright (C) 2017 by @vruz

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'trollop'
require './slit_commands.rb'


class String
    def yellow
        STDERR.puts(self.y+self+self.r)
    end
    def cyan
        STDERR.puts(self.c+self+self.r)
    end
    def reset
        STDERR.puts(self.r+self)
    end

    def to_yellow
        self.y+self+self.r
    end

    def to_cyan
        self.c+self+self.r
    end

    def to_blue
        self.b+self+self.r
    end
    
    def to_reset
        self.r+self
    end

    # COLORTERM is set in various terminals like 
    # rxvt, gnome terminal, etc.
    # Some others only set the TERM variable.
    # CLICOLOR is an OS X setting that enables ANSI 
    # escape color codes on the Mac OS X Terminal
    def y
        return ((!"#{ENV['COLORTERM']}".empty?) or ("#{ENV['TERM']}"=~/xterm/) or ("#{ENV['CLICOLOR']}"=="1")) ? "\033[33m" : "" 
    end
    def b
        return ((!"#{ENV['COLORTERM']}".empty?) or ("#{ENV['TERM']}"=~/xterm/) or ("#{ENV['CLICOLOR']}"=="1")) ? "\033[34m" : "" 
    end
    def c
        return ((!"#{ENV['COLORTERM']}".empty?) or ("#{ENV['TERM']}"=~/xterm/) or ("#{ENV['CLICOLOR']}"=="1")) ? "\033[36m" : "" 
    end
    def r
        return ((!"#{ENV['COLORTERM']}".empty?) or ("#{ENV['TERM']}"=~/xterm/) or ("#{ENV['CLICOLOR']}"=="1")) ? "\033[0m"  : ""
    end
end

def justdie(txt)
    Trollop::die "#{txt}".to_yellow
end

ansi="ANSI TERM"
COMMANDS = %w(new use dbs tables schema def add get set del row state)

$opts = Trollop::options do
  version "slit 1.0 - Copyright (C) 2017 by @vruz"
  banner <<-EOS

#{ansi.r}slit 1.0
#{ansi.c}--------
#{ansi.y}slit is a simple command to insert, delete, and extract data from basic 
#{ansi.y}sqlite3 databases, following some minimum conventions that abstract 
#{ansi.y}the user from the bore of dealing with SQL for the most simple tasks.
#{ansi.c}
Usage:#{ansi.y}

     slit [options] command <parameters>

#{ansi.c}Available commands:

     #{ansi.y}#{COMMANDS.join(' ')}
#{ansi.r}
slit new <database>            # create new database
slit use <database>            # use existing database
slit dbs ["pattern"]           # list databases 
slit tables ["pattern"]        # list tables in database
slit schema [tablename]        # list structure of a table

slit get <lookupfield>=<value> # fetch rows that match
slit get <lookupfield>=<value> [ / <fieldlist> ]
slit row <rownumber>           # fetch one row

slit add <data1>[,data2,data3] # add data to table    
slit set <lookupfield>=<value> / <field1>=<v1>[,<field2>=<v2>,...]

slit del <rownumber>           # delete a row 
slit del <lookupfield>=<value>

#{ansi.c}Options: 

#{ansi.y}  Options that don't take a value are flags. 
#{ansi.y}  When a flag is specified, it means that its value is on.
#{ansi.y}  When you need to turn it off use its --no-<option>
#{ansi.y}  counterpart. For example:  --no-rownumbers #{ansi.r}
\n\n
EOS

  opt :path,        "Directory path where the database resides",    :default => File.join(Dir.home,".slit")
  opt :table,       "Table name where data is stored",              :default => "slitdata"
  opt :format,      "Output data format. One of: [#{ansi.y}txt#{ansi.r}|#{ansi.y}tab#{ansi.r}|#{ansi.y}ascii#{ansi.r}|#{ansi.y}json#{ansi.r}|#{ansi.y}csv#{ansi.r}]", :default => "txt"
  opt :columnlabels,"Output column names in csv and txt formats",   :default => false
  opt :rownumbers,  "Output row numbers for every row",             :default => false  
  opt :maxrows,     "Maximum number of rows to output",             :default => 20
  opt :query,       "Display query that is being executed",         :default => false
  opt :silent,      "Don't display any status messages",            :default => false

  stop_on COMMANDS
end

cmd = ARGV.shift

if cmd!=nil then
    if COMMANDS.index(cmd) then
        exec = "slit_#{cmd}".to_sym
        if !respond_to?(exec,true) then
            justdie  "Command not defined"
        end
        # new use def add get del row state
        case cmd 
            when "new" 
                dbname = ARGV.shift
                dbname="#{dbname}"
                if !dbname.empty? then
                    slit_new(dbname) 
                else
                    justdie  "New database name not specified"
                end

            when "use"
                dbname = ARGV.shift
                dbname="#{dbname}"
                if !dbname.empty? then
                    slit_use(dbname) 
                else
                    justdie "Database name not specified"
                end                
            else
                parameters = ARGV.join(" ")
                send exec,parameters
        end
    else
        justdie "Unknown command #{cmd.inspect}"
    end
else
    justdie "No valid command specified"
end