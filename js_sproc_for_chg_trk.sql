/*************************************************************************************************************
Script:             Detect and enable change tracking
Create Date:        2022-03-20
Author:             Gopal Raghavan
Description:        Stored Procedure to enable change tracking for all objects in outbound shares


Copyright © 2023 Snowflake Inc. All rights reserved
*************************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author                              Comments
------------------- -------------------                 --------------------------------------------
2023-03-20          G. Raghavan                         Initial Creation
*************************************************************************************************************/

//set the roles and the warehouse
use role accountadmin;
//use whatever warehouse. Xsmall is ok
//the warehouse needs to be created as a prerequisite
use warehouse osr;

//create the database to hold all the audit objects
create database snowflake_sproc;
create schema sproc;

//create temporary tables to hold all the objects for audit purposes
//if need be the word TEMPORARY can be removed to create permanent tables
CREATE OR REPLACE TEMPORARY TABLE SHARE_DESC
(DESC_STMT VARCHAR)
COMMENT = 'CONTAINS DESCRIBE STATEMENTS FOR EVERY SHARE';

CREATE OR REPLACE TEMPORARY TABLE SHARE_AND_TYPE
(SHARE_TYPE_OBJ VARCHAR,
SHARE_NAME VARCHAR)
COMMENT = 'CONTAINS THE TYPE OF OBJECT OF EACH OUTBOUND SHARE';

CREATE OR REPLACE TEMPORARY TABLE SHARE_VIEW_TABLE_REF
(VIEW_NAME VARCHAR,
TABLE_NAME VARCHAR)
COMMENT = 'CONTAINS ALL THE TABLES REFERENCES BY THE VIEWS WHICH ARE PART OF AN OUTBOUND SHARE';

CREATE OR REPLACE TEMPORARY TABLE CHANGE_TRACKING_AUDIT
(ALTER_ACTION VARCHAR)
COMMENT = 'CONTAINS THE LOG OF ALL THE ALTER CHANGE_TRACKING ACTIONS';


//***********************************************************************
//THIS BLOCK CREATES THE STORED PROCEDURE
//***********************************************************************
create or replace procedure enable_change_tracking()
  returns string not null
  language javascript
  execute as caller
  as     
  $$ 

    function alter_table_view(typestr,tblview) {
        if (typestr == "TABLE") {
            stmt = 'ALTER TABLE ' +tblview+ ' SET CHANGE_TRACKING = TRUE';
        }
        else {
            stmt = 'ALTER VIEW ' +tblview+ ' SET CHANGE_TRACKING = TRUE';
        }
        sql_stmt = snowflake.createStatement({sqlText: stmt});
        try {
                sql_cmd = sql_stmt.execute();
                var alter_success_stmt = 'INSERT INTO CHANGE_TRACKING_AUDIT (ALTER_ACTION) VALUES (\'' +tblview+ ' WAS SET TO CHANGE_TRACKING = TRUE\')';
                var alter_success_cmd = snowflake.createStatement({sqlText: alter_success_stmt});
                var alter_success = alter_success_cmd.execute();
            }
        catch(err){
            //grab all the error information
            var result =  "Failed: Code: " + err.code + "  State: " + err.state;
            //remove the "'" from table name in the error message
            const lastIndex = err.message.lastIndexOf('\'');
            const after = err.message.slice(lastIndex + 1);
            //tack on the sliced message
            result += "  Message: " + after;
            result += " Stack Trace: " + err.stackTraceTxt;
            
            var alter_err_stmt = 'INSERT INTO CHANGE_TRACKING_AUDIT (ALTER_ACTION) VALUES (\'' +tblview+ ' encountered error: ' + result+ '\')';
            var alter_err_cmd = snowflake.createStatement({sqlText: alter_err_stmt});
            var alter_err = alter_err_cmd.execute();
        }
        return "table or view was attempted to be altered";
    }
    
    var my_sql_command = "show shares";
    var statement1 = snowflake.createStatement( {sqlText: my_sql_command} );
    var result_set1 = statement1.execute();

    var first_sql_cmd = 'SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) where "kind" = \'OUTBOUND\'';
    var first_sql_stmt = snowflake.createStatement({sqlText: first_sql_cmd});
    var res_first_sql = first_sql_stmt.execute();
    
    //Add all the shares with a DESCRIBE COMMAND into the DESC table
    
    while (res_first_sql.next())  {
       
       //Read share name
       var share = res_first_sql.getColumnValue(1);
       var share_str = '(\'DESCRIBE SHARE ' +share+ ' \')';
       var desc_share_cmd = 'INSERT INTO SHARE_DESC (DESC_STMT) VALUES ' +share_str;
       var prep_stmt = snowflake.createStatement({sqlText: desc_share_cmd});
       var exec_stmt = prep_stmt.execute();
       
       }
       
    //loop through the DESC table and execute the statement
    //And pick up the name and kind from the RESULT_SCAN function

    var desc_stmt = 'SELECT * FROM SHARE_DESC';
    var desc_cmd = snowflake.createStatement({sqlText: desc_stmt});
    var desc_exec = desc_cmd.execute();

    //execute each statment in a loop

    while (desc_exec.next()){

        var desc_share_name = desc_exec.getColumnValue(1);
        var prep_desc_stmt = snowflake.createStatement({sqlText: desc_share_name});
        var prep_desc_cmd = prep_desc_stmt.execute();

        while (prep_desc_cmd.next()) {
            var pickup_view_table_stmt = 'SELECT "kind", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) where "kind" IN (\'TABLE\', \'VIEW\')';
            pickup_view_table_cmd = snowflake.createStatement({sqlText: pickup_view_table_stmt});
             res_pickup_view_table = pickup_view_table_cmd.execute();

             //Add the components on each share into SHARE_AND_TYPE table

             while (res_pickup_view_table.next()) {

                var type_str = res_pickup_view_table.getColumnValue(1);
                var name_str = res_pickup_view_table.getColumnValue(2);
                var pickup_view_tbl_stmt = 'INSERT INTO SHARE_AND_TYPE (SHARE_TYPE_OBJ, SHARE_NAME) VALUES (\'' +type_str+ '\', \'' +name_str+ '\')';
                var pickup_view_tbl_cmd = snowflake.createStatement({sqlText: pickup_view_tbl_stmt});
                var pickup_view_tbl_exec = pickup_view_tbl_cmd.execute();

             }

          break;
            
        }
        
    }

    //Now that the table SHARE_AND_TYPE has been populated,
    //set CHANGE_TRACKING = TRUE for all tables;

    var chg_trk_tbl_stmt = 'SELECT SHARE_NAME FROM SHARE_AND_TYPE WHERE SHARE_TYPE_OBJ = \'TABLE\'';
    var chg_trk_tbl_cmd = snowflake.createStatement({sqlText: chg_trk_tbl_stmt});
    var chg_trk_tbl_exec = chg_trk_tbl_cmd.execute();

    while (chg_trk_tbl_exec.next()) {

        //loop through the tables
        var tbl = chg_trk_tbl_exec.getColumnValue(1);
        //call function to set change_tracking to TRUE
        var typestr = 'TABLE';
        var chg_trk_tbl_true_exec = alter_table_view(typestr, tbl);
    }

    //First the views need to have change tracking set to true
    //We have to figure out all the tables that are referencing the view objects

    var view_obj_stmt = 'SELECT SHARE_NAME FROM SHARE_AND_TYPE WHERE SHARE_TYPE_OBJ = \'VIEW\'';
    var view_obj_cmd = snowflake.createStatement({sqlText: view_obj_stmt});
    var view_obj_exec = view_obj_cmd.execute();

    while (view_obj_exec.next()) {
        var view = view_obj_exec.getColumnValue(1);
        var view2 = view;
        //we need to trim all database and schema names from the table name
        view2 = view2.split(".").pop();
        
        var get_ref_table_name_stmt = 'SELECT REFERENCED_OBJECT_NAME FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES WHERE REFERENCING_OBJECT_NAME = ' +'\'' +view2+ '\'' + ' AND REFERENCED_OBJECT_DOMAIN = \'TABLE\'';
        var get_ref_table_cmd = snowflake.createStatement({sqlText: get_ref_table_name_stmt});
        var get_ref_table_exec = get_ref_table_cmd.execute();

        while (get_ref_table_exec.next()) {
            var tbl = get_ref_table_exec.getColumnValue(1);
            var view_tbl_stmt = 'INSERT INTO SHARE_VIEW_TABLE_REF(VIEW_NAME, TABLE_NAME)VALUES (\'' +view+ '\', \'' +tbl+ '\')';
            var view_tbl_cmd = snowflake.createStatement({sqlText: view_tbl_stmt});
            var view_tbl_exec = view_tbl_cmd.execute();
        }

        //set the change_tracking to true for all the first level views
        var typestr = 'VIEW';
        var chg_trk_view_true_exec = alter_table_view(typestr, view);
    }

    //finally set change_tracking to true for all second level tables
    var second_lvl_stmt = 'SELECT VIEW_NAME, TABLE_NAME FROM SHARE_VIEW_TABLE_REF';
    var second_lvl_cmd = snowflake.createStatement({sqlText: second_lvl_stmt});
    var second_lvl_exec = second_lvl_cmd.execute();

    while (second_lvl_exec.next()) {
        var typestr = 'TABLE';
        var schema_name = second_lvl_exec.getColumnValue(1);
        const lastIndex = schema_name.lastIndexOf('.');
        const before = schema_name.slice(0, lastIndex);
        var tbl = second_lvl_exec.getColumnValue(2);
        var tbl = before+'.'+tbl;
        var chg_trk_tbl_true_exec = alter_table_view(typestr, tbl);
    }
    
  return "success"; // Replace with something more useful.
  $$
  ;

call enable_change_tracking();

//uncomment for audit

//SELECT * FROM SHARE_DESC;
//SELECT * FROM SHARE_AND_TYPE; 
//SELECT * FROM SHARE_VIEW_TABLE_REF;
//SELECT * FROM CHANGE_TRACKING_AUDIT;
