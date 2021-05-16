(: Copyright (c) 2008, 2010, Oracle and/or its affiliates. All rights reserved. :)
import module namespace osmpiplog = "http://xmlns.oracle.com/communications/ordermanagement/pip/omspiplog" at "http://xmlns.oracle.com/communications/ordermanagement/pip/omspiplog/LogModule.xquery";

declare namespace ordertaskconst = "java:oracle.communications.ordermanagement.automation.OsmPipTaskConstant";
declare namespace context = "java:com.mslv.oms.automation.OrderNotificationContext";
declare namespace log = "java:org.apache.commons.logging.Log";
declare namespace xQueryExtension = "java:oracle.communications.ordermanagement.extensionpoint.XQueryExtension";
declare namespace xQueryExtensionContext = "java:oracle.communications.ordermanagement.extensionpoint.XQueryExtensionContext";

declare namespace oms="urn:com:metasolv:oms:xmlapi:1";

declare variable $context external;
declare variable $automator external;
declare variable $log external;

declare variable $ORDER_FAILED_HANDLER_URI := "http://xmlns.oracle.com/communications/ordermanagement/o2acombase/orderstate_handling/OrderFailedStateHandler.xquery";
declare variable $ORDER_ABORTED_HANDLER_URI := "http://xmlns.oracle.com/communications/ordermanagement/o2acombase/orderstate_handling/OrderAbortedStateHandler.xquery";
declare variable $ORDER_INPROGRESS_HANDLER_URI := "http://xmlns.oracle.com/communications/ordermanagement/o2acombase/orderstate_handling/OrderInProgressStateHandler.xquery";
declare variable $ORDER_CANCELLED_HANDLER_URI := "http://xmlns.oracle.com/communications/ordermanagement/o2acombase/orderstate_handling/OrderCancelledStateHandler.xquery";

declare variable $CF_OPERATOR := "osm";
declare variable $PARAM_CONTEXT := "context";
declare variable $PARAM_AUTOMATOR := "automator";
declare variable $PARAM_LOG := "log";
declare variable $PARAM_SECURE := "secureToken";

declare variable $MODULE_NAME := "OrderStateChangeHandler";

let $orderData := fn:root(.)/oms:GetOrder.Response
let $orderId := fn:normalize-space($orderData/oms:OrderID/text())
let $orderState := fn:normalize-space($orderData/oms:OrderState/text())
let $secureToken := context:getOsmCredentialPassword($context, $CF_OPERATOR)
let $xqyExtension := xQueryExtension:createExtensionContext()
(: Setup XQuery context parameters :)
let $setParameters :=
    <oms:SetParameters>
    {
        xQueryExtensionContext:setParameter($xqyExtension, $PARAM_CONTEXT, $context),
        xQueryExtensionContext:setParameter($xqyExtension, $PARAM_AUTOMATOR, $automator),
        xQueryExtensionContext:setParameter($xqyExtension, $PARAM_LOG, $log),
        xQueryExtensionContext:setParameter($xqyExtension, $PARAM_SECURE, $secureToken)
    }
    </oms:SetParameters>
(: Call XQuery extension  :)    
let $handlerResult :=
    <oms:HandlerResult>
    {
        if (fn:exists($setParameters))
        then
        (
            if ($orderState = ordertaskconst:ORDER_IN_PROGRESS())
            then xQueryExtension:invoke($xqyExtension, $ORDER_INPROGRESS_HANDLER_URI, $orderData)
            else if ($orderState = ordertaskconst:ORDER_FAILED())
            then xQueryExtension:invoke($xqyExtension, $ORDER_FAILED_HANDLER_URI, $orderData)
            else if ($orderState = ordertaskconst:ORDER_ABORTED())
            then xQueryExtension:invoke($xqyExtension, $ORDER_ABORTED_HANDLER_URI, $orderData)
            else if ($orderState = ordertaskconst:ORDER_CANCELLED())
            then xQueryExtension:invoke($xqyExtension, $ORDER_CANCELLED_HANDLER_URI, $orderData)
            else if ($orderState = ordertaskconst:ORDER_COMPLETED())
            then () (: Order complete state change is not handled order completion event is handle by other automator :)
            else if ($orderState = ordertaskconst:ORDER_AMENDING())
            then ()
            else if ($orderState = ordertaskconst:ORDER_CANCELLING())
            then ()
            else if ($orderState = ordertaskconst:ORDER_SUSPENDED())
            then ()
            else ()
        )
        else ()
    }
    </oms:HandlerResult>
(: Log if enabled  :)    
let $logActivity :=
    <oms:LogActivity>
    {
        if (log:isDebugEnabled($log) = fn:true())
        then osmpiplog:logOrderActivityToFile($MODULE_NAME, $orderId, $orderId, $handlerResult)
        else ()    
    }
    </oms:LogActivity>
(: Return nothing :)    
where (fn:exists($logActivity))        
return
    $handlerResult/oms:Null