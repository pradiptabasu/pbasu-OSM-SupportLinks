# pbasu-OSM-SupportLinks

# OSM Logging
* https://community.oracle.com/message/14884122
* https://docs.oracle.com/communications/E79201_01/doc.735/e79206/adm_bea_wls_console.htm#OSMSA703
* Operations: How to use logging in OSM 7.3.x (Doc ID 2223714.1)
* 
* 
* https://docs.oracle.com/cd/E49311_01/doc.724/e41607/dsosm_dyn_comp_xqry.htm#DSOSM668
https://docs.oracle.com/cd/E49311_01/doc.724/e41607/dsosm_xqry_ext_aut.htm
https://docs.oracle.com/cd/E57026_01/doc.73/e57032/dsosm_comp_xqry.htm#DSOSM701
* https://docs.oracle.com/communications/E79102_01/doc.735/e79100/share_dev_sce_autom.htm#DSOSM676
* https://docs.oracle.com/communications/E79201_01/doc.735/e79208/share_dev_sce_autom.htm#CHDBGFHJ
* https://community.oracle.com/thread/4192906

declare namespace log = "java:org.apache.commons.logging.Log”;
declare variable $log external;
log:info($log,concat('Received SOM Status Update: SOM_Failed; ', $response/su:status/text())),
    automator:setUpdateOrder($automator,"true"),
    context:completeTaskOnExit($context,"failure"),
    (
        <OrderDataUpdate xmlns="http://www.metasolv.com/OMS/OrderDataUpdate/2002/10/25">
            {
            for $item in $items
            for $parent in $item/su:ParentLineId
            for $orderComponentItem in $component/oms:orderItem[oms:orderItemRef/oms:LineXmlData/so:SalesOrderLine/corecom:Identification/corecom:ApplicationObjectKey/corecom:ID/text() = $parent/text()]
            return (
                    <Update path="{fn:concat("/ControlData/Functions/Provision/orderItem[@index='",fn:data($orderComponentItem/@index),"']")}">
                       <ExternalFulfillmentState>{$item/su:Status/text()}</ExternalFulfillmentState>
                    </Update>    
              )
                 
            }
        </OrderDataUpdate>
    )
    
    

# OSM XQuery Functions - Oracle® Communications Design Studio Modeling OSM Orchestration Release 7.2.4
* https://docs.oracle.com/cd/E49311_01/doc.724/e41610/dscom_xqry_functions.htm#DSCOM451
* https://docs.oracle.com/cd/E41514_01/doc.724/e41519/shared_cpt_sce_xqury.htm#OSMCN575
* 
* 

# Oracle® Communications Order and Service Management Cartridge Guide for Oracle Application Integration Architecture Release 2.0.1
* https://docs.oracle.com/cd/E39423_01/doc.201/e35422/cr_cart_operations.htm#autoId0

# Oracle Communications Order and Service Management Cartridges for Oracle Application Integration Architecture Online Documentation Library, Release 2.1.0
* https://docs.oracle.com/cd/E41611_01/doc.21/e41612/cr_cart_extending.htm#OSMCR417

# XQuery Examples - Oracle Communications Order and Service Management Online Documentation Library, Release 7.3.5
* https://docs.oracle.com/communications/E79201_01/doc.735/e79209/shared_cpt_sce_xqury.htm#OSMMG1108

* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
* 
