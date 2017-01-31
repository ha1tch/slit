# slit
## A trivial tool for trivial SQLite3 tasks

A simple command for basic sqlite data handling

slit is a simple command to insert, delete, and extract data from basic 
sqlite3 databases, following some minimum conventions and a unix-like,
regular syntax that abstracts the user from the bore of dealing with 
SQL for the most simple tasks.

Dox here:
https://raw.githubusercontent.com/vruz/slit/master/slitdoc.txt


![slit screenshot](/slit-screenshot.png)

    Usage:

         slit [options] command <parameters>

    Available commands:

         new use dbs tables schema def add get set del row state

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

    Options: 

      Options that don't take a value are flags. 
      When a flag is specified, it means that its value is on.
      When you need to turn it off use its --no-<option>
      counterpart. For example:  --no-rownumbers 
      -p, --path=<s>        Directory path where the database resides (default: /home/vruz/.slit)
      -t, --table=<s>       Table name where data is stored (default: slitdata)
      -f, --format=<s>      Output data format. One of: [txt|tab|ascii|json|csv] (default: txt)
      -c, --columnlabels    Output column names in csv and txt formats
      -r, --rownumbers      Output row numbers for every row
      -m, --maxrows=<i>     Maximum number of rows to output (default: 20)
      -q, --query           Display query that is being executed
      -s, --silent          Don't display any status messages
      -v, --version         Print version and exit
      -h, --help            Show this message
