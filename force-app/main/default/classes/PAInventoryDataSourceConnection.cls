/**
 *   Extends the DataSource.Connection class to enable 
 *   Salesforce to sync the external system’s schema 
 *   and to handle queries and searches of the external data. 
 **/
global class PAInventoryDataSourceConnection extends
    DataSource.Connection {
    private DataSource.ConnectionParams connectionInfo;
    
    /**
     *   Constructor for DriveDataSourceConnection
     **/
    global PAInventoryDataSourceConnection(
        DataSource.ConnectionParams connectionInfo) {
        this.connectionInfo = connectionInfo;
    }
    
    /**
     *   Called when an external object needs to get a list of 
     *   schema from the external data source, for example when 
     *   the administrator clicks “Validate and Sync” in the 
     *   user interface for the external data source.   
     **/
     
    override global List<DataSource.Table> sync() {
        List<DataSource.Table> tables = new List<DataSource.Table>();
        List<DataSource.Column> inventoryColumns = new List<DataSource.Column>();
        inventoryColumns.add(DataSource.Column.url('DisplayUrl'));
        inventoryColumns.add(DataSource.Column.text('ExternalId'));
        inventoryColumns.add(DataSource.Column.text('Title'));
        inventoryColumns.add(DataSource.Column.textarea('Description'));
        inventoryColumns.add(DataSource.Column.text('Category'));
        inventoryColumns.add(DataSource.Column.number('Quantity', 18, 0));
        inventoryColumns.add(DataSource.Column.number('Price', 18, 2));
        inventoryColumns.add(DataSource.Column.url('Picture_Url'));
        tables.add(DataSource.Table.get('Inventory', 'Title', inventoryColumns));
        
        return tables;
        } 

    /**
     *   Called to query and get results from the external 
     *   system for SOQL queries, list views, and detail pages 
     *   for an external object that’s associated with the 
     *   external data source.
     *   
     *   The QueryContext argument represents the query to run 
     *   against a table in the external system.
     *   
     *   Returns a list of rows as the query results.
     **/
    override global DataSource.TableResult query(
        DataSource.QueryContext context) {
        DataSource.Filter filter = context.tableSelection.filter;
        String url;
        if (filter != null) {
            String thisColumnName = filter.columnName;
            if (thisColumnName != null && 
                    thisColumnName.equals('ExternalId'))
                url = 'callout:PAInventory' + '/' +filter.columnValue;
            else
                url = 'callout:PAInventory';
        } else {
            url = 'callout:PAInventory';
        }

        /**
         * Filters, sorts, and applies limit and offset clauses.
         **/
        List<Map<String, Object>> rows = 
            DataSource.QueryUtils.process(context, getData(url));
        return DataSource.TableResult.get(true, null,
            context.tableSelection.tableSelected, rows);
    }

    /**
     *   Called to do a full text search and get results from
     *   the external system for SOSL queries and Salesforce
     *   global searches.
     *   
     *   The SearchContext argument represents the query to run 
     *   against a table in the external system.
     *   
     *   Returns results for each table that the SearchContext 
     *   requested to be searched.
     *
    override global List<DataSource.TableResult> search(
        DataSource.SearchContext context) {
        List<DataSource.TableResult> results =
            new List<DataSource.TableResult>();

        for (Integer i =0;i< context.tableSelections.size();i++) {
            String entity = context.tableSelections[i].tableSelected;
            String url = 
                'https://gw-cc1sandbox.api.us-east.philips-healthsuite.com/store/fhir/hts/Organization/'+
                '?q=fullText+contains+\''+context.searchPhrase+'\'';
            results.add(DataSource.TableResult.get(
                true, null, entity, getData(url)));
        }

        return results;
    } **/
    
    override global List<DataSource.UpsertResult> upsertRows(DataSource.UpsertContext c) {
        System.Debug('in upsert');
        List<DataSource.UpsertResult> results = new List<DataSource.UpsertResult>();
        for (Map<String,Object> row: c.rows) {
            Map<String,Object> updatedRows = new Map<String,Object>();
            String id = (String)row.get('ExternalId');
            for (String key : row.keySet()) {
                if (key.equals('ExternalId')) {
                    updatedRows.put('ItemId', row.get(key));
                } else if (key.equals('Picture_URL')) {
                    updatedRows.put('PictureURL', row.get(key));
                } else if (key.equals('DisplayUrl')) {
                    continue;
                } else {
                    updatedRows.put(key, row.get(key));
                }
            }
            
            String jsonRecord = (String)JSON.serialize(updatedRows);
            System.Debug('jsonRecord --> '+ jsonRecord);
            HttpResponse response;
            try {
                if (updatedRows.size() > 0) {
                    if (updatedRows.containsKey('ItemId')) {
                        response = getResponse('callout:PAInventory','PUT',jsonRecord);
                    }
                    else {
                        response = getResponse('callout:PAInventory','POST',jsonRecord);
                    }
                } 
      

            } catch (DataSource.DataSourceException e) {
                System.debug(e.getMessage());
            }
            
            Map<String, Object> m = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
            if (response.getStatusCode() == 200){
                results.add(DataSource.UpsertResult.success(
                    String.valueOf(m.get('id'))));
              } 
              else {
                 results.add(DataSource.UpsertResult.failure(
                         String.valueOf(m.get('id')), 
                         'The callout resulted in an error: ' + 
                         response.getStatusCode()));
              }
            
        }
        return results;
    }

    /**
     *   Helper method to parse the data.
     *   The url argument is the URL of the external system.
     *   Returns a list of rows from the external system.
     **/
    public List<Map<String, Object>> getData(String url) {
        HttpResponse response = getResponse(url,'GET','');

        List<Map<String, Object>> rows =
            new List<Map<String, Object>>();

        Map<String, Object> responseBodyMap = (Map<String, Object>)
            JSON.deserializeUntyped(response.getBody());

        /**
         *   Checks errors.
         **/
        Map<String, Object> error =
            (Map<String, Object>)responseBodyMap.get('error');
        if (error!=null) {
            List<Object> errorsList =
                (List<Object>)error.get('errors');
            Map<String, Object> errors =
                (Map<String, Object>)errorsList[0];
            String errorMessage = (String)errors.get('message');
            throw new DataSource.OAuthTokenExpiredException(errorMessage);
        }

        List<Object> fileItems=(List<Object>)responseBodyMap.get('inventory');
        if (fileItems != null) {
            for (Integer i=0; i < fileItems.size(); i++) {
                Map<String, Object> item = 
                    (Map<String, Object>)fileItems[i];
                rows.add(createRow(item));  
            }
        } else {
            rows.add(createRow(responseBodyMap));
        }

        return rows;
    }

    /**
     *   Helper method to populate the External ID and Display 
     *   URL fields on external object records based on the 'id' 
     *   value that’s sent by the external system.
     *   
     *   The Map<String, Object> item parameter maps to the data 
     *   that represents a row.
     *   
     *   Returns an updated map with the External ID and 
     *   Display URL values.
     **/
    public Map<String, Object> createRow(
        Map<String, Object> item){
        Map<String, Object> row = new Map<String, Object>();
        for ( String key : item.keySet() ) {
            if (key == 'ItemId') {
                row.put('ExternalId', item.get(key));
            } else if (key=='link') {
                row.put(key, item.get(key));
                row.put('DisplayUrl', item.get(key));
            } else if (key=='PictureURL') {
                row.put('Picture_Url', item.get(key));
            } else {
                row.put(key, item.get(key));
            }
        }
        return row;
    }
    
    /**
     *   Helper method to make the HTTP GET call.
     *   The url argument is the URL of the external system.
     *   Returns the response from the external system.
     **/
    public HttpResponse getResponse(String url,String method,String body) {
        Http httpProtocol = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndPoint(url);
        request.setMethod(method);
        if (method != 'GET') {
            request.setHeader('Content-Type', 'application/json');
            request.setBody(body);
        }
        System.Debug('request --> '+ request);
        //request.setHeader('Authorization', 'Bearer '+
        //    this.connectionInfo.oauthToken);
        //request.setHeader('api-version','1');
        //request.setHeader('tenant','hts');    
        HttpResponse response = httpProtocol.send(request);
        return response;
    }
}