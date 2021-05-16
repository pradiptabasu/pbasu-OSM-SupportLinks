declare namespace osm="urn:com:metasolv:oms:xmlapi:1";
declare namespace log = "java:org.apache.commons.logging.Log"; 
declare namespace im="http://xmlns.oracle.com/MilestoneMessage";

(:below lines on xsl and saxon are required for printing XMLs:)
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare option saxon:output "method=xml";
declare option saxon:output "saxon:indent-spaces=2";

declare variable $log external; 

declare variable $context external;
declare variable $automator external;


let $inputDoc := self::node()
let $order := fn:root(.)/osm:GetOrder.Response
let $salesOrderRevision := $order/osm:_root/osm:OrderHeader/osm:salesOrderRevision/text()
let $orderState := fn:normalize-space($order/osm:OrderState/text())

let $inputDocStr := if (fn:exists($inputDoc))
                	then
                		saxon:serialize($inputDoc, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)
                	else ""
                  
return (
  log:info($log,concat('numSalesOrder: ',$order/osm:Reference/text())), 
  log:info($log,concat('numOrder: ',$order/osm:OrderID/text())),
  log:info($log,concat('salesOrderRevision: ',$salesOrderRevision)), 
  
  (: Below prints only values and no tags. XML needs to be serialized before logging.
  log:info($log,concat('Order: ',$order)),
  :)
  (:Below prints the XML in full structure --->  inputDocStr serialized earlier
  log:info($log,concat('Input Doc: ',$inputDocStr)), 
  :)
  
  
  
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
	    
	    
	    
  <im:requestResponse xmlns:im="http://xmlns.oracle.com/MilestoneMessage">
	  <im:numSalesOrder>{$order/osm:Reference/text()}</im:numSalesOrder>
	  <im:salesOrderRevision>{$salesOrderRevision}</im:salesOrderRevision>
	  <im:numOrder>{$order/osm:OrderID/text()}</im:numOrder>
	  <im:typeOrder>{$order//osm:OrderHeader/osm:typeOrder/text()}</im:typeOrder>
	  <im:errorCode>00</im:errorCode>
	  <im:status>Fulfillment Complete</im:status>
	  <im:message>Order {$order/osm:Reference/text()} Complete</im:message>
  </im:requestResponse>
)