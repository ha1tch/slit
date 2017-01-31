
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


require 'pp'
require 'json'
require 'fileutils'
require 'sqlite3'
$changed = false

class Object
    def is(klass) 
        klass = klass.to_s if klass.class.to_s=="Symbol"
        return self.class.to_s==klass
    end
end

module Lookupable
    def lookup(lookupindex,lookupvalue,returnindex)
        isarray = self.class == Array 
        self.each_with_index {|element,index| 
            record = isarray ? element : element.last      
            if record[lookupindex]==lookupvalue then 
                return record[returnindex] 
            end                    
        }
        return nil
    end
end
class Array
    include Lookupable
end
class Hash
    include Lookupable
end

a = [ ["Mercury", "Hg", 80, 200.592 ],
      ["Argon",   "Ar", 18,  39.948 ],
      ["Chromium","Cr", 24,  51.9961] ] 
#  a.lookup(1,"Ar",3)  # returns atomic weight of Argon

h = {  "Hg" => { name: "Mercury",  atomicno: 80, weight: 200.592 },
       "Ar" => { name: "Argon",    atomicno: 18, weight:  39.948 },
       "Cr" => { name: "Chromium", atomicno: 24, weight:  51.9961}  }

#  Return the name of the element whose atomic number is 18
#  h.lookup(:atomicno,18,:name) 


class String
    def alpha?
        match(/^[[:alnum:]]+$/)
    end

    def integer?
        begin
            Integer(self)
        rescue
            nil
        end
    end

    def float?
        begin
            Float(self)
        rescue
            nil
        end
    end
end



def w(txt)
    "#{txt}".yellow if !$opts[:silent]
end

def retrieve_state
    dirname = File.join(Dir.home,'.slit')
    unless File.directory?(dirname)
        begin
            FileUtils.mkdir_p(dirname)
        rescue
            justdie "Can't create slit directory"
        end
    end

    statefile = File.join(Dir.home,'.slit','slit.state')
    if File.exists?(statefile) then
        begin
            state = JSON.parse(File.read(statefile),{symbolize_names: true})
            changed = $opts.keys.grep(/_given/)
            
            if changed.size > 0 then 
                changed.each {|key|
                    keyname = key.to_s.rpartition("_")[0].to_sym
                    state[keyname] = $opts[keyname]
                    $changed=true
                }
                
                $opts = state.clone
            end

            return state
        rescue
            justdie "Couldn't retrieve slit state"
        end
    else
            save_state
            return $opts
    end

end


def save_state
    statefile = File.join(Dir.home,'.slit','slit.state')

    begin
        tosave = $opts.clone
        tosave.delete(:help)
        tosave.delete(:version)
        
        jsondata = JSON.pretty_generate(tosave)

        sfile=File.open(statefile, File::CREAT|File::TRUNC|File::RDWR, 0644)
        sfile.write(jsondata)
        sfile.close
    rescue
        justdie "Couldn't save slit state"
    end
end

def slit_state(bogus)
    state=retrieve_state
    pp state 
    $opts = state.clone
    if $changed then
        save_state 
        w "slit state updated"
    end
end

def slit_new(dbname)
    state = retrieve_state
    fname = File.join(state[:path],dbname+'.db')
    if File.exists?(fname) then
        justdie "Database already exists: #{fname}"
    end

    begin
        db = SQLite3::Database.new fname
        db.close
    rescue
        justdie "Can't create database: #{fname}"
    end
    state[:dbname]=dbname
    w "Database created: #{dbname}"
    $opts = state.clone
    save_state
end

def slit_use(dbname)
    state = retrieve_state
    $opts = state.clone

    db = opendb(dbname)
    db.close
    state[:dbname]=dbname
    w "Database in use: #{dbname}"
    $opts = state.clone
    save_state
end

def opendb(dbname)

    if "#{dbname}".empty? then
        justdie "No database specified"
    end

    fname = File.join($opts[:path],dbname+'.db')

    if !File.exists?(fname) then
        justdie "File for database does not exist: #{fname}"
    end

    begin
        db = SQLite3::Database.open fname
        return db
    rescue
        justdie "Can't open database: #{fname}"
    end
end

def slit_def(fieldefs)
    state = retrieve_state
    $opts = state.clone

    if !state[:dbname] then 
        justdie "No database is currently in use"
    end

    fieldefs = fieldefs.split(",")
    if fieldefs.size == 0 then
        justdie "A list of column definitions must be specified in format:  <columname>:[fieldtype]"
    end

    coldefs = {}
    valid_column_types = [:number, :string, :text]

    # unused. delete later if not needed
    # sqltypes = {number: "NUMERIC(15,5)", string: "VARCHAR(255)", text: "TEXT"}
    flatdefs = []

    fieldefs.each {|fdef|
        adef = fdef.partition(":")
        fieldname = adef[0].strip
        fieldtype = adef[2].strip
        if !fieldname.alpha? then
            justdie "Invalid field name #{fieldname}"
        end
        if fieldtype.empty? then
            fieldtype = "string"
        end
        fieldtype = fieldtype.to_sym

        if !valid_column_types.index(fieldtype) then
            justdie "Invalid type #{fieldtype} for field #{fieldname}"
        end
        #puts "#{fieldname} #{fieldtype}"
        coldefs[fieldname]=fieldtype
        flatdefs << "#{fieldname} #{fieldtype}"
    }
    # if not exists 
    sql = "create table #{$opts[:table]} ("
    sql << flatdefs.join(",")
    sql << ")"

    db=opendb(state[:dbname])
    execute_query(db,sql,onfail: "Couldn't create table #{opts[:table]} definition")

    w "Field definitions applied"
    $opts = state.clone
    save_state if $changed
end

def slit_add(data)
    state = retrieve_state
    $opts = state.clone

    data = data.split(",")
    if data.size == 0 then 
        justdie "Data not specified"
    end
    
    data.map! {|value| 
        value=value.strip 
        if value.integer? or value.float? then
            value
        else
            value='"' +value+'"' 
        end
    }

    insert_command = "insert into #{$opts[:table]} values ( " +  data.join(", ") + " )"

    db=opendb($opts[:dbname])

    execute_query(db, insert_command,
                      onfail:    "Can't insert: #{insert_command}", 
                      onsuccess: "Data inserted OK" )

    $opts=state.clone
    save_state if $changed

end


def format_header(columns)
    header=""
    case $opts[:format]
        when "csv"
            if $opts[:columnlabels] then
                header=columns.keys.join(",")+"\n"
            else
                header=""
            end

        when "ascii"
            frametop="+".to_yellow
            columns.each {|field,fielddata|
                size=fielddata.first
                frametop << ("-"*size+"+").to_yellow
            }
            namestop="|".to_yellow
            
            columns.each {|field,fielddata|
                    size=fielddata.first
                    namestop << field.center(size).to_reset+"|".to_yellow
            }
            header=frametop
            if $opts[:columnlabels] then
                header="#{frametop}\n#{namestop}\n#{frametop}\n"
            else
                header=frametop+"\n"
            end
            return header
    end

    # no headers for txt,tab,or json
    return header
end

def format_footer(columns)
    case $opts[:format]
        when "ascii"
            framebottom="+".to_yellow
            columns.each {|field,fielddata|
                size=fielddata.first
                type=fielddata.last 
                framebottom << ("-"*size+"+").to_yellow
            }
            framebottom << "\n"
            return framebottom
        else
            return ""
    end
end

def format_row(arow,columns=nil)
    arow.delete_if{|k,v| k.integer? }
    fmt = $opts[:format].to_sym
    cols = $opts[:columnlabels]
    case fmt
        when :txt
            txt = ""
            if cols then
                arow.each {|k,v| txt << "#{k+':'} #{v}\n"}
            else
                arow.each {|k,v| txt << "#{v}\n"}
            end                
            return txt

        when :tab 
            return arow.values.join("\t")+"\n"

        when :ascii
            rowtxt = "|".to_yellow
            if columns.is(:Hash) then
                arow.each {|k,v|
                    colwidth=columns[k].first
                    coltype =columns[k].last  
                    colwidth=12 if !colwidth.is(:Fixnum)
                    coltype ="number" if !coltype.is(:String)

                    if coltype=="number" then
                        rowtxt <<  v.to_s.rjust(colwidth).to_reset+"|".to_yellow
                    else
                        rowtxt <<  v.to_s.ljust(colwidth).to_reset+"|".to_yellow
                    end
                }

            else
                arow.each {|k,v| rowtxt <<  v.to_s.ljust(12).to_reset+"|".to_yellow}
            end
            return rowtxt+"\n"

        when :json
            return arow.to_json+"\n"

        when :csv    
            return arow.values.join(",")+"\n"
        
        else
            justdie "Unknown format #{$opts[:format]}"
    end
end

def table_schema(db,tablename)
    return execute_query(db,"PRAGMA table_info('#{tablename}');")
end

def lookup_hash(array,lookupfield,lookupvalue,returnfield)
    # Can't use Array#find here, I don't want to return the element
    # of the array, but only the value specified by returnfield
    array.each{|hash| if hash["#{lookupfield}"]=="#{lookupvalue}" then return hash["#{returnfield}"] end }
    return nil
end

def format_table(db,tablename,results)
    columndata=execute_query(db,"PRAGMA table_info('#{tablename}');")
    data=[]; columnsizes={}
    results.each {|row| data << row }

    data.each {|row|
        row.each{|fieldname,pair|
            value = pair

            if fieldname.is(:String) then
                if columnsizes[fieldname]==nil then
                    columnsizes[fieldname]=[fieldname.size,lookup_hash(columndata,"name",fieldname,"type" )]
                end

                fieldstring=value.to_s
                if fieldstring.size > columnsizes[fieldname].first then
                        columnsizes[fieldname][0]=fieldstring.size 
                end
            end 
        }
    }

    txt = format_header(columnsizes)
    data.each {|r| txt << format_row(r,columnsizes) }
    txt << format_footer(columnsizes)
    return txt
end

def slit_row(rownumber)
    if !rownumber.integer? then
        justdie "Row number must be an integer"
    end
    rownumber = Integer(rownumber)
    state = retrieve_state
    $opts = state.clone

    db = opendb($opts[:dbname])

    rows = $opts[:rownumbers] ? "oid," : ""
    select_command = "select #{rows} * from #{$opts[:table]} where oid=#{rownumber} "

    db.results_as_hash = true
    arow = execute_query(db,select_command)

    if arow.size==0 then
        w "Row not found."
    else
        puts format_table(db,$opts[:table],arow)
    end
    save_state if $changed
end


def slit_del(rownumber)
    if !rownumber.integer? then
        justdie "Row number must be an integer"
    end
    rownumber = Integer(rownumber)
    state = retrieve_state
    $opts = state.clone

    db = opendb($opts[:dbname])

    rows = $opts[:rownumbers] ? "oid," : ""
    delete_command = "delete from #{$opts[:table]} where oid=#{rownumber} "

    execute_query(db,delete_command)
    rowsaffected = db.changes

    if rowsaffected == 1 then
        w "Row #{rownumber} deleted."
    elsif rowsaffected == 0
        w "No rows were deleted."
    else
        w "#{rowsaffected} rows deleted" # This should never happen
    end

    save_state if $changed
end


def slit_get(query)
    state = retrieve_state
    $opts = state.clone

    ############### parse parameters #################

    colseparator="/"
    manyparams=(" "+query.strip+" ").partition("#{colseparator}")
    manyparams.map!{|e| e.strip }
    params = manyparams[0]
    colspec = manyparams[2]
    colfields = colspec.split(",")
    colfields.map!{|e| e.strip }
    params = params.strip.partition("=")

    inputlookupspec=false
    inputlookupgood=false
   
    params.collect!{|a| a.empty? ? nil : a } 
    if params.none? then
        inputlookupspec=false
        inputlookupgood=true
    elsif params.any? and !params.all?
        inputlookupspec=true
        inputlookupgood=false
    else
        inputlookupspec=true 
        inputlookupgood=true
    end

    if !inputlookupgood then 
        justdie "Command must be in the form: slit get [<lookupfield>=<value>] [/ fieldlist]"
    end

    ############### lookup validation ###############

    db = opendb($opts[:dbname])
    tabledef=table_schema(db,$opts[:table]) 
    db.results_as_hash = true

    if inputlookupspec
        fieldname=params[0]
        fieldvalue=params[2]
        if !fieldname.alpha? then
            justdie "Invalid fieldname #{fieldname}"
        end
        if fieldvalue.integer? then
            fieldvalue=Integer(fieldvalue)
        elsif fieldvalue.float? 
            fieldvalue=Float(fieldvalue)
        else
            fieldvalue="\"#{fieldvalue}\""
        end

        if !tabledef.rassoc(fieldname).is(:Array) then
            justdie "The lookup field '#{fieldname}' does not exist in table '#{$opts[:table]}'"
        end
    end


    ########### column fields validation ##########

    queryfields="*"
    if manyparams[1]==colseparator then
        colfields.each{|d|
            if !tabledef.rassoc(d).is(:Array) then
                justdie "There is no column '#{d}' in table '#{$opts[:table]}'"
            end
        }

        # this was clever, but lack of this clever 
        # thing is more practical and useful 
        # if !colfields.index(fieldname) and !"#{fieldname}".empty? then
        #   colfields.unshift(fieldname)
        # end

        if colfields.size>0 then
            queryfields=colfields.join(",")
        end
    end

    if inputlookupgood and inputlookupspec then
        lookupclause="where #{fieldname}=#{fieldvalue}"
    else
        lookupclause=""
    end

    ############## on to the querying #############

    queryfields = $opts[:rownumbers] ? "oid,#{queryfields}" : queryfields
    select_command = "select #{queryfields} from #{$opts[:table]} #{lookupclause} limit #{$opts[:maxrows]}"
    arow = execute_query(db,select_command)

    if arow.size==0 then
        w "No rows found."
    else
        puts format_table(db,$opts[:table],arow)
    end

    save_state if $changed
end



def slit_set(query)
    state = retrieve_state
    $opts = state.clone

    ############### parse parameters #################

    colseparator="/"
    slitseteducate="slit set <lookupfield>=<value> / <field1>=<v1>[,<field2>=<v2>,...]"
    manyparams=(" "+query.strip+" ").partition("#{colseparator}")
    manyparams.map!{|e| e.strip }
    params = manyparams[0]
    colspec = manyparams[2]
    colfields = colspec.split(",")
    colfields.map!{|e| e.strip }
    params = params.strip.partition("=")

    inputlookupspec=false
    inputlookupgood=false
   
    params.collect!{|a| a.empty? ? nil : a } 
    if params.none? then
        inputlookupspec=false
        inputlookupgood=true
    elsif params.any? and !params.all?
        inputlookupspec=true
        inputlookupgood=false
    else
        inputlookupspec=true 
        inputlookupgood=true
    end

    if !inputlookupgood or !inputlookupspec then 
        justdie "Command must be in the form: "+slitseteducate
    end

    ############### lookup validation ###############

    db = opendb($opts[:dbname])
    tabledef=table_schema(db,$opts[:table]) 
    db.results_as_hash = true

    if inputlookupspec
        fieldname=params[0]
        fieldvalue=params[2]
        if !fieldname.alpha? then
            justdie "Invalid fieldname #{fieldname}"
        end
        if fieldvalue.integer? then
            fieldvalue=Integer(fieldvalue)
        elsif fieldvalue.float? 
            fieldvalue=Float(fieldvalue)
        else
            fieldvalue="\"#{fieldvalue}\""
        end

        if !tabledef.rassoc(fieldname).is(:Array) then
            justdie "The lookup field '#{fieldname}' does not exist in table '#{$opts[:table]}'"
        end
    end


    ########### column fields validation ##########

    updatefields=""
    if manyparams[1]==colseparator then
        cleansets=[]

        colfields.each{|acol|
            parseupdate=acol.partition("=")
            colname  = parseupdate.first.strip
            colvalue = parseupdate.last.strip

            coldef=tabledef.rassoc(colname)

            if !coldef.is(:Array) then
                justdie "There is no column '#{colname}' in table '#{$opts[:table]}'"
            end
            if colvalue.empty? then
                w "The correct syntax is: "+slitseteducate
                justdie "No value was specified to update '#{colname}'"
            end

            # TODO: Something needs to be done here in case the database wasn't 
            # created with slit. Other tools and other users will surely have
            # different data types in their column definitions.
            
            case coldef[2]  # this holds the data type for the field
                when "string"  
                    cleansets << colname+"='#{colvalue}'"
                when "number"
                    cleansets << colname+"=#{colvalue}"
                else
                    # We caught something different here. Warn the user for now.
                    w "WARN: Unknown column type #{coldef['type']}. Assuming it's a string type."
                    cleansets << "#{colname}='#{colvalue}'"
            end
        }

        if colfields.size>0 then
            updatefields=cleansets.join(",")
        end
    end

    if inputlookupgood and inputlookupspec then
        lookupclause="where #{fieldname}=#{fieldvalue}"
    else
        w "The correct syntax for the command is: "+slitseteducate
        justdie "A lookup clause must be specified"
    end

    if updatefields.empty? then
        w "The correct syntax for the command is: "+slitseteducate
        justdie "No fields specified."
    end


    ############## on to the querying #################

    update_command = "update #{$opts[:table]} set #{updatefields} #{lookupclause}"
    results = execute_query(db,update_command)
    #w update_command
    rowsaffected = db.changes

    if rowsaffected == 0
        w "No updates done."
    else
        w "#{rowsaffected} rows updated." 
    end
    save_state if $changed
end


def slit_tables(pattern)
    state = retrieve_state
    $opts = state.clone

    db = opendb($opts[:dbname])
    if !"#{pattern}".empty? then
        query_pattern = " and name like '#{pattern}'"
        query_pattern.gsub!("*","%")
    else
        query_pattern = ""
    end

    select_command="select name from sqlite_master where type='table'#{query_pattern} order by name;"
    rows=execute_query(db,select_command,onfail: "Couldn't retrieve a list of tables".to_yellow)

    if rows.size==0 then
        if !"#{pattern}".empty? then
            w "No tables found with the specified pattern: #{pattern}."
        else
            w "No tables in database."
        end
    else
        howmany=0
        w "Tables in database '#{$opts[:dbname]}'"
        rows.each do |row|
            puts row.first
            howmany = howmany+1
        end   
        if howmany==1
            w "1 table listed."
        else
            w "#{howmany} tables listed."
        end
    
    end
    save_state if $changed
end


def execute_query(db, sql, onfail: "Couldn't execute query: #{sql}".to_yellow, onsuccess: "")
    if "#{sql}".empty? then 
        Trollop.die "No query specified"
    end

    begin
        w "Executing query: #{sql}" if $opts[:query]
        rows = db.execute sql

        if !onsuccess.empty? then
            w onsuccess
        end
    rescue
        justdie onfail
    end
    return rows
end

# the parameter tablename can also be specified with the -t option
# if it's specified as a parameter and not as an option, the command
# parameter will take precedence, the default table setting won't be
# affected, and the slit state won't be altered.
def slit_schema(tablename)   
    state = retrieve_state  
    $opts = state.clone

    db = opendb($opts[:dbname])

    if "#{tablename}".empty? then
        tablename=$opts[:table]
    end

    # We got no table specified as command parameter 
    # nor an option in the command line, nor it is 
    # available in the slit state. Can't do this then. 
    if "#{tablename}".empty? then
        justdie "No table specified"
    end

    select_command  = "select name from sqlite_master where name='#{tablename}';"
    onfail          = "Couldn't retrieve table schema for #{tablename}"
    rows=execute_query( db, select_command, onfail: onfail)

    if rows.size==0 then
        justdie "Table '#{tablename}' does not exist in database '#{$opts[:dbname]}'"
    end
 
    select_command  = "PRAGMA table_info('#{tablename}');"
    onfail          = "Couldn't retrieve table schema for #{tablename}"
    rows=execute_query( db, select_command, onfail: onfail)

    if rows.size==0 then
        justdie "WTF error: A table should have at least one field to even exist."
    else
        w "Schema for table '#{tablename}' in database '#{$opts[:dbname]}'"

        columnformat="%03s %-15s %s"
        puts columnformat % ["No.","Column","Type"]
        puts columnformat % ["="*3,"="*15,"="*10]

        rows.each do |row|
            puts columnformat % [row[0], row[1], row[2]]
        end   
    end
    save_state if $changed
end


def slit_dbs(pattern)
    # find a way to avoid globbing without altering shell settings
    # http://stackoverflow.com/questions/11456403/stop-shell-wildcard-character-expansion
    state = retrieve_state  
    $opts = state.clone

    if "#{pattern}".empty? then
        pattern="*.db"
    else
        # Search patterns involving the wildcard * won't work 
        # on most unices due to globbing. If the user needs to
        # use this, the pattern must be specified between quotes 
        # like:  slit dbs "backup_number_*"
        pattern="#{pattern}.db" 
    end
    files=Dir.glob($opts[:path]+"/#{pattern}").sort
    dblisted = 0
    w "Databases in #{$opts[:path]}"
    files.each{|filename| 
        dbname=File.basename(filename).rpartition(".").first

        begin
            # it's not enough to just open a database file, sqlite won't fail
            # it "opens" any crap you throw at it, so you have to force reading
            # something that must be there to make sure it's really a database
            db = SQLite3::Database.open filename
            db.execute "select name from sqlite_master"
            db.close 
            puts dbname
            dblisted=dblisted+1
        rescue
            # Do nothing if it's not a database,
            # ignore and move on to the next.
            # puts "skipped #{dbname}"
        end
    }
    if dblisted == 0 then 
        dblisted="No databases"
    elsif dblisted==1 then
        dblisted="1 database" 
    else
        dblisted="#{dblisted} databases"
    end
    w "#{dblisted} found."

    save_state if $changed
end