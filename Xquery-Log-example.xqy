import module namespace orderdetails = "orderdetails" at "http://xmlns.ptcl.com/ordermanagement/somorderfulfillment/utilities/functions/OrderDetailsMappingModule.xquery";

declare namespace oms= "urn:com:metasolv:xmlapi:1";
declare namespace automator = "java:oracle.communications.ordermanagement.automation.plugin.ScriptReceiverContextInvocation";
declare namespace context = "java:com.mslv.oms.automation.TaskContext";
declare namespace log = "java:org.apache.commons.logging.Log";
declare namespace saxon = "http://saxon.sf.net/";
declare namespace xsl = "http://www.w3.org/1999/XSL/Transform";
declare namespace cat= "http://www.ibm.com/decomposeCustomerOrderService/";

declare variable $automator external;
declare variable $context external;
declare variable $log external;

declare option saxon:output "method=xml";
declare option saxon:output "saxon:indent-spaces=4";
 
let $catalogResponse := .
let $orderNumber := $catalogResponse/decomposeCustomerOrder/orderNumber/text()
let $CatalogResponseCode := $catalogResponse/returnCode/text()
let $taskDataOrder := fn:root(automator:getOrderAsDOM($automator))/oms:GetOrder.Response
 
(:let $offeredService:= $catalogResponse/decomposeCustomerOrder/offeredServices/item:)

let $xmlSerialized := saxon:serialize($catalogResponse, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)

let $logStr := fn:concat($orderNumber,"|Catalog Response Received|",$xmlSerialized)

return
    (
		automator:setUpdateOrder($automator, 'true'),
		<OrderDataUpdate>
			<UpdatedNodes>
				<_root>
					<decompositionDetails>
						<productsList>  
						{  
							for $productItem in $catalogResponse/decomposeCustomerOrder/offeredServices/item/products/item  
							let $idProductItem := $productItem/id/text()  
							let $CFSItems := $catalogResponse/decomposeCustomerOrder/offeredServices/item/customerServices/item[parentProduct/id/text() = $idProductItem]  
							let $logStr1 := fn:concat("|ID Product ITEM |",$idProductItem)  
							return  
							(  
								log:info($log,$logStr1),  
								<productItem>  
									<productID>{$productItem/text()}</productID>  
								</productItem>,  
								log:info($log,"After product Item close tag")  
							)   
						}  
						</productsList> 
					</decompositionDetails>
				</_root>
			</UpdatedNodes>
		</OrderDataUpdate>,
		log:info($log, $logStr),
		context:completeTaskOnExit($context, 'success')
    )
	
	
	
	
	
===============================================================================================================================================================


 