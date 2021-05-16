(: Copyright (c) 2008, 2010, Oracle and/or its affiliates. All rights reserved. :)
import module namespace orderstatefn = "http://xmlns.oracle.com/communications/ordermanagement/pip/orderstatefn" at "http://xmlns.oracle.com/communications/ordermanagement/pip/orderstatefn/OrderStateUtilityModule.xquery";
import module namespace osmfalloutpip = "http://xmlns.oracle.com/communications/ordermanagement/pip/fallout" at "http://xmlns.oracle.com/communications/ordermanagement/pip/fallout/TroubleTicket.xquery";
import module namespace osmwebservicemodule = "http://xmlns.oracle.com/communications/ordermanagement/pip/osmwebservicemodule" at "http://xmlns.oracle.com/communications/ordermanagement/pip/osmwebservicemodule/OsmWebServiceModule.xquery";
import module namespace osmpiplog = "http://xmlns.oracle.com/communications/ordermanagement/pip/omspiplog" at "http://xmlns.oracle.com/communications/ordermanagement/pip/omspiplog/LogModule.xquery";
import module namespace comqueryviewconstants = "http://xmlns.oracle.com/communications/ordermanagement/o2acombase/comqueryviewconstants" at "http://xmlns.oracle.com/communications/ordermanagement/o2acombase/constants/QueryViewConstants.xquery";
import module namespace ordereventmodule = "http://xmlns.oracle.com/communications/ordermanagement/pip/ordereventmodule" at "http://xmlns.oracle.com/communications/ordermanagement/pip/ordereventmodule/FulfillmentOrderEventModule.xquery";
import module namespace pipbreakpointfn = "http://xmlns.oracle.com/communications/ordermanagement/pip/pipbreakpointmodule" at "http://xmlns.oracle.com/communications/ordermanagement/pip/pipbreakpointmodule/BreakpointControlModule.xquery";

declare namespace saxon="http://saxon.sf.net/";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";

declare namespace context = "java:com.mslv.oms.automation.OrderContext";
declare namespace automator =  "java:oracle.communications.ordermanagement.automation.plugin.ScriptReceiverContextInvocation";
declare namespace log = "java:org.apache.commons.logging.Log";
declare namespace osmError = "java:com.mslv.oms.OMSErrorCodes";
declare namespace dateUtil = "java:oracle.communications.ordermanagement.util.date.DateUtil";
declare namespace ordertaskconst = "java:oracle.communications.ordermanagement.automation.OsmPipTaskConstant";
declare namespace collection = "java:java.util.Collection";
declare namespace iterator = "java:java.util.Iterator";
declare namespace UUID = "java:java.util.UUID";
declare namespace javaString = "java:java.lang.String";

declare namespace salesord="http://xmlns.oracle.com/EnterpriseObjects/Core/EBO/SalesOrder/V2";
declare namespace corecom="http://xmlns.oracle.com/EnterpriseObjects/Core/Common/V2";
declare namespace oms="urn:com:metasolv:oms:xmlapi:1";

declare variable $GTX := "GlobalTransaction";
declare variable $ORDER_CREATION_FALLOUT_PREFIX := "OSM-ORDER-CREATION-FAIL-ORDER-ID.";
declare variable $MODULE_NAME := "OrderFailedStateHandler";

declare variable $context external;
declare variable $automator external;
declare variable $log external;
declare variable $secureToken external;

declare function local:getAttachedSalesOrderEBM() as element()?
{
    let $names := context:getAllAttachmentFileNames($context)
    return
        if (fn:exists($names)) 
        then
        (
            let $name := $names[1]
            return
                if (fn:exists($name)) 
                then saxon:parse(context:getAttachmentAsString($context, xs:string($name)))/salesord:ProcessSalesOrderFulfillmentEBM
                else ()
        )
        else ()
};

declare function local:populateOrderData (
    $orderId as xs:string,
    $orderKey as xs:string,
    $salesOrderEbm as element())
{
    let $request := 
        <UpdateOrder.Request xmlns="urn:com:metasolv:oms:xmlapi:1">
            <OrderID>{ $orderId }</OrderID>
            <View>{ $comqueryviewconstants:COM_QUERY_VIEW }</View>
            <UpdatedNodes>
                <_root>
                    <messageXmlData>{ $salesOrderEbm }</messageXmlData>
                    <EbmHeaderXmlData>{$salesOrderEbm/corecom:EBMHeader}</EbmHeaderXmlData>
                    <CustomerHeaders>
                        <Identification>
                            <ID>{ xs:string(UUID:randomUUID()) }</ID>
                        </Identification>
                    </CustomerHeaders>
                    <Fallout>
                        <orderCreationFallout>{ $orderKey }</orderCreationFallout>
                    </Fallout>
                </_root>
            </UpdatedNodes>   
        </UpdateOrder.Request>
        
    let $responseDoc := context:processXMLRequestDom($context, $request)
    return
        if (fn:exists($responseDoc/oms:UpdateOrder.Error))
        then
        (
            let $responseDocStr := saxon:serialize($responseDoc, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)
            let $msg := fn:concat("Error on OrderFailedStateHandler->populateOrderData - ", $responseDocStr)
            return
            	fn:error(xs:QName('osmError:ORDER_UPDATE_FAILED'), $msg)
        )
        else ()        
};

declare function local:generatePayload(
    $orderId as xs:string,
    $isCreationFailure as xs:boolean,
    $errorMessage as xs:string?, 
    $salesOrderEbm as element()?) as element()?
{
    if ($isCreationFailure = fn:true() and fn:exists($salesOrderEbm))
    then
    (
        if (fn:contains($errorMessage, $GTX))
        then
        (
            (: 
             : This is a temp workaround before the GlobalTransaction error problem is fixed in the core.
             : What is does is resend the order back to the web service queue and allow that to be retry
             :) 
            osmwebservicemodule:createOrderRequestEx($comqueryviewconstants:COM_OPERATOR, $secureToken, $salesOrderEbm)
        )
        else 
        (
            let $correlationId := fn:concat($ORDER_CREATION_FALLOUT_PREFIX, $orderId)
            let $errorSeverity := osmfalloutpip:getErrorSeverity($errorMessage)
            let $errorCode := osmfalloutpip:getErrorCode($errorMessage)
            let $revision := 
                if (fn:exists($salesOrderEbm/salesord:DataArea/salesord:ProcessSalesOrderFulfillment/corecom:Identification/corecom:Revision/corecom:Number)) 
                then ($salesOrderEbm/salesord:DataArea/salesord:ProcessSalesOrderFulfillment/corecom:Identification/corecom:Revision/corecom:Number/text()) 
                else ( "Unknown Revision" )
            let $timestamp := dateUtil:convertOsmDateTimeToAIAformat(dateUtil:getCurrentDateTime())
            let $customerPartyReference := $salesOrderEbm/salesord:DataArea/salesord:ProcessSalesOrderFulfillment/corecom:CustomerPartyReference

            let $accountName := if (fn:exists($customerPartyReference/corecom:CustomerPartyAccountName)) 
                         then ($customerPartyReference/corecom:CustomerPartyAccountName/text()) 
                         else ( "Unknown AccountName" )
            let $orderKey := 
                if (fn:exists($salesOrderEbm/salesord:DataArea/salesord:ProcessSalesOrderFulfillment/corecom:Identification/corecom:ID)) 
                     then ($salesOrderEbm/salesord:DataArea/salesord:ProcessSalesOrderFulfillment/corecom:Identification/corecom:ID/text()) 
                     else ( "Unknown OrderKey" )
            
            let $ordernotifEBM := 
                osmfalloutpip:createFalloutNotification(
                    $salesOrderEbm, 
                    $orderKey,
                    $correlationId,
                    $osmfalloutpip:OSM_CFS_IDENTIFIER,
                    $errorCode,
                    concat($osmfalloutpip:SUBMISSION_FALLOUT_FLAG,$errorMessage),
                    $errorSeverity,
                    $revision,
                    $timestamp,
                    $accountName,
                    $customerPartyReference)
                    
            let $copyEbmToOrder := 
                <oms:CopyEbmToOrder>
                {
                    local:populateOrderData($orderId, $orderKey, $salesOrderEbm)
                }
                </oms:CopyEbmToOrder>
            where (fn:exists($copyEbmToOrder))
            return            
                osmwebservicemodule:createOrderRequestEx($comqueryviewconstants:COM_OPERATOR, $secureToken, $ordernotifEBM)
         )            
    )
    else ()
};

let $orderData := fn:root(.)/oms:GetOrder.Response
let $orderId := fn:normalize-space($orderData/oms:OrderID/text())
let $orderStateHist := orderstatefn:getOrderStateHistory($context, $orderId)
let $isCreationFailure := orderstatefn:isCreationFailure($orderStateHist)
let $salesOrderEbm := 
    if ($isCreationFailure = fn:true()) 
    then local:getAttachedSalesOrderEBM() 
    else ()
let $orderKey := 
    if (fn:exists($salesOrderEbm/salesord:DataArea/salesord:ProcessSalesOrderFulfillment/corecom:Identification/corecom:ID)) 
         then ($salesOrderEbm/salesord:DataArea/salesord:ProcessSalesOrderFulfillment/corecom:Identification/corecom:ID/text()) 
         else ( "Unknown OrderKey" )
let $debugControl := pipbreakpointfn:getDebugControl($orderKey)         
let $failureReason :=         
    if ($isCreationFailure = fn:true())
    then orderstatefn:getFailReason($orderStateHist, ordertaskconst:ORDER_FAILED())[1]/text()
    else ()
let $errorMessage := 
    if (fn:exists($failureReason))
    then
    (
        if (fn:contains($failureReason, "OrderTransactionNotAllowedFault") and fn:contains($failureReason, "reason["))
        then fn:substring-after(fn:substring-before($failureReason, "], condition["), "reason[")
        else $failureReason
    )                                    
    else "Unknown ErrorMessage"

let $createOrderPayload := local:generatePayload($orderId, $isCreationFailure, $errorMessage, $salesOrderEbm)
let $logActivity :=
    <oms:LogActivity>
    {
        if (log:isDebugEnabled($log) = fn:true())
        then
        (
            let $orderDatalog :=
                <oms:OrderDatalog>
                    <oms:OrderData>{$orderData}</oms:OrderData>
                    <oms:SalesOrderEbm>{$salesOrderEbm}</oms:SalesOrderEbm>
                    <oms:OrderKey>{$orderKey}</oms:OrderKey>
                    <oms:FailureReason>{$failureReason}</oms:FailureReason>
                    <oms:ErrorMessage>{$errorMessage}</oms:ErrorMessage>
                    <oms:CreateOrderPayload>{$createOrderPayload}</oms:CreateOrderPayload>
                    <oms:OrderStateHist>{$orderStateHist}</oms:OrderStateHist>
                </oms:OrderDatalog>
            return
                osmpiplog:logOrderActivityToFile($MODULE_NAME, $orderKey, $orderId, $orderDatalog)
        )
        else ()            
    }
    </oms:LogActivity>    
where (fn:exists($createOrderPayload) and fn:exists($logActivity))
return
    <oms:HandleOrderFailed>
        <oms:CallAutomationApi>
        {
            automator:setUpdateOrder($automator, "false")
        }
        </oms:CallAutomationApi>
        <oms:CreateFalloutOrderOrReCreateOriginalOrder>
        {
            orderstatefn:sendWebServiceRequest($createOrderPayload)
        }
        </oms:CreateFalloutOrderOrReCreateOriginalOrder>
        <oms:FulfillmentOrderEvent>
        {
            ordereventmodule:fireFulfillmentOrderFailedEvent($context, $log, $orderData, $debugControl, $comqueryviewconstants:ORDER_EVENT_NOTIFICATION_VIEW)
        }
        </oms:FulfillmentOrderEvent>
    </oms:HandleOrderFailed>    
    

