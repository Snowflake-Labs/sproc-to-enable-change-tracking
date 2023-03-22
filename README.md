# Javascript stored procedure to detect and enable change tracking for tables & views in all outbound shares

Copyright (c) 2023 Snowflake Inc. All rights reserved.

####################################################################################################### 
This code is not part of the Snowflake Service and is governed by the terms in LICENSE.txt, unless expressly agreed to in writing.  Your use of this code is at your own risk, and Snowflake has no obligation to support your use of this code.
#######################################################################################################



A few things to keep in mind:

1.  The warehouse needs to be created before executing the commands in this file.  The warehouse can be x-small.
2.  The database and schema names for the temporary tables and the stored procedure can be changed as needed.
3.  The tables to store actions for audit purposes have been defined as TEMPORARY.  These can be made permanent tables if need be.  Temporary tables will automatically be dropped if the session is expired or expires.
4.  The name of the stored procedure can be changed to suit the user's naming standards.
5.  A try and catch block is only defined for the function alter_table_view.  Best practices are to define it for all actions where we prepare and execute sql statements. I'll be adding these gradually over time.
6.  Also, the alter_table_view function DOES NOT need two blocks (one for TABLE and the other for VIEW).  I put it in there for testing and debugging.  The ALTER statement can be toggled with one block using the tblview variable between a TABLE and a VIEW.  I'll be changing it over time.
7.  The javascript variables can be undefined and deleted to optimize memory.  I'll be doing that over time as well.
8.  To look at all the running statements in the procedure, you can use the role of an ACCOUNTADMIN or any other role that has the privilege to see the query history in Snowsight.  To access query history, click on Activity -> Query History on the left side menu.

USAGE:
Copy and paste the contents of the file in an individual worksheet (NOT PART OF A FOLDER) in Snowsight and run.

NOTE:
This script has been tested a few times in my environment and it works well.  Please inspect the temporary tables and the query history to ensure that change tracking was enabled correctly for all objects in outbound shares as needed.

This will only work for first and second level tables.  In other words, if a view is built on top of other views, it will not unravel the tables underneath the second-level view(s) to enable change_tracking.  If the first-level views are built on top of tables, it can enable change_tracking for those tables(second-level) but not levels below.
