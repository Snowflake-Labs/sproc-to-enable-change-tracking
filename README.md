# sproc-to-enable-change-tracking
Javascript stored procedure to detect and enable change tracking for all outbound shares


A few things to keep in mind:

1.  The warehouse needs to be created before executing the commands in this file.  The warehouse can be x-small.
2.  The database and schema names can be changed as needed.
3.  The tables to store actions for audit purposes have been defined as TEMPORARY.  These can be made permanent tables if need be.  Temporary tables will automatically be dropped if the session is expired or expires.
4.  The name of the stored procedure can be changed to suit the user's naming standards.
5.  A try and catch block is only defined for the function alter_table_view.  Best practices are to define it for all actions where we prepare and execute sql statements. I'll be adding these gradually over time.
6.  To look at all the running statements in the procedure, you can use the role of an ACCOUNTADMIN or any other role that has the privilege to see the query history in Snowsight.  To access query history, click on Activity -> Query History on the left side menu.

USAGE:
Copy and paste the contents of the file in an individual worksheet (NOT PART OF A FOLDER) in Snowsight and run.

NOTE:
This script has been tested a few times in my environment and it works well.  Please inspect the temporary tables and the query history to ensure that change tracking was enabled correctly for all objects in outbound shares as needed.

This will only work for first and second level tables.  In other words, if a view is built on top of other views, it will not unravel the tables underneath the second-level view(s) to enable change_tracking.  If the first-level views are built on top of tables, it can enable change_tracking for those tables(second-level) but not levels below.
