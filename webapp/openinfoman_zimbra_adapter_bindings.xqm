module namespace page = 'http://basex.org/modules/web-page';

import module namespace rscript = "https://github.com/openhie/openinfoman/adapter/r";
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace csr_proc = "https://github.com/openhie/openinfoman/csr_proc";
import module namespace oi_csv = "https://github.com/openhie/openinfoman/adapter/csv";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";
import module namespace functx = 'http://www.functx.com';

declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace csd = "urn:ihe:iti:csd:2013";


declare function page:redirect($redirect as xs:string) as element(restxq:redirect)
{
  <restxq:redirect>{ $redirect }</restxq:redirect>
};

declare function page:nocache($response) {
(<http:response status="200" message="OK">  

  <http:header name="Cache-Control" value="must-revalidate,no-cache,no-store"/>
</http:response>,
$response)
};



(:Supposed to be linked into header of a web-page, such as the OpenHIE Health Worker Registry Management Interface :)
declare
  %rest:path("/CSD/adapter/zimbra/{$query_name}/{$doc_name}")
  %rest:GET
  %output:method("xhtml")
  function page:show_doc_info($query_name,$doc_name) 
{ 
  (: For the form, note there is a bit of cheating here... really this should done with an extension or something.   :)
  let $link := concat( $csd_webconf:baseurl ,"CSD/adapter/zimbra/" , $query_name, "/" , $doc_name, "/speciality_search")
  let $zimbra_link := concat( $csd_webconf:baseurl ,"CSD/adapter/zimbra/" , $query_name, "/" , $doc_name, "/zimbra_user_list.zmp")
  let $speciality_svs_id := "1.3.6.1.4.1.21367.200.109"
  let $contents := 
  <div class='container'>
    <h2>Speciality Search</h2>
    <form action="{$link}">
       <label for='speciality'>Speciality:</label>
       <select name='speciality'>
         <option value=''>Select A Speciality</option>
         { 
	   for $concept in svs_lsvs:get_single_version_value_set($csd_webconf:db,$speciality_svs_id )//svs:Concept
	   let $val := concat($concept/@code, "@@@",$concept/@codeSystem)
	   return <option value="{$val}">{string($concept/@displayName)}</option>
	 }
       </select>
       <br/>
       <label for='city'>Location (City):</label>
       <select name='city'>
         <option value=''>Select A City</option>
         { 
	   let $cities := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:facilityDirectory/csd:facility/csd:address[@type="Practice"]/csd:addressLine[@component="city"]/text()
	   return 
	     for $city in $cities
	   return <option value="{$city}">{$city}</option>
	 }
       </select>
       <div class='pull-right'>
	 <input type='submit' value='Search'/>
       </div>
    </form>
    <h2>Zimbra User List</h2>
    <a href="{$zimbra_link}">Get Zimbra User Creation List</a>

    Download the list to the file zimbra_user_list.zmp and use the "zmprov" command.
    You can find more information <a href="http://wiki.zimbra.com/wiki/Bulk_Provisioning">here</a> on Zimbra bulk user creation.

    For example:
    <pre>
      sudo su zimbra
      wget {$zimbra_link}
      zmprov -f zimbra_user_list.zmp
    </pre>


  </div>
  return page:wrapper($contents)
};



(: such a specific thing shouldn't be here.  should be generalized somehow :)
declare
  %rest:path("/CSD/adapter/zimbra/{$query_name}/{$doc_name}/zimbra_user_list.zmp")
  %rest:GET
  %output:method("text")
  function page:speciality_search($query_name,$doc_name)
{ 
  let $function := csr_proc:get_function_definition($csd_webconf:db,$query_name)
  let $host := ($function/csd:extension[@type='zimbra_host' and @urn='urn:openhie.org:openinfoman:adapter:zimbra'])[1]
  let $create :=
    for $provider in csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:providerDirectory/csd:provider
    let $demo:= $provider/csd:demographic[1]
    let $sn := $demo/csd:name[1]/csd:surname/text()
    let $gn := $demo/csd:name[1]/csd:forename/text()
    let $dn := concat($gn, " " , $sn)
    return concat("createAccount " , string($provider/@oid) , "@" , $host , "  password displayName '", $dn , "' givenName '" , $gn , "' sn '", $sn , "'
")
 return $create
};

(: such a specific thing shouldn't be here.  should be generalized somehow :)
declare
  %rest:path("/CSD/adapter/zimbra/{$query_name}/{$doc_name}/speciality_search")
  %rest:GET
  %rest:query-param("city", "{$city}")
  %rest:query-param("speciality", "{$speciality}")
  %output:method("xhtml")
  function page:speciality_search($query_name,$doc_name,$city,$speciality) 
{ 
 let $code := substring-before($speciality,'@@@')
 let $codingScheme := substring-after($speciality,'@@@')
 let $providers_0 := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:providerDirectory/csd:provider
 let $providers_1 := 
   if ($code and $codingScheme)
   then
     for $provider in $providers_0    
     where exists($provider/csd:specialty[@code=$code and @codingScheme = $codingScheme])
     return $provider
   else $providers_0
 let $providers_2 := 
   if ($city) 
   then 
      for $provider in $providers_1
      let $fac_oids :=  $provider/csd:facilities/csd:facility/@oid
      let $facs := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:facilityDirectory/csd:facility[@oid = $fac_oids and ./csd:address[@type='Practice' and ./csd:addressLine[@component = 'city'] = $city]]
      where count($facs) > 0
      return $provider
   else $providers_1

 let $provider_list := 
   <ul>
     {
       for $provider in $providers_2 
       let $demo:= $provider/csd:demographic[1]
       let $oid := string($provider/@oid)
       let $adapter_link := concat($csd_webconf:baseurl,"CSD/adapter/zimbra/" , $query_name, "/" , $doc_name,"/scheduling")
       return 
       <li>
	 {$demo/csd:name[1]/csd:surname/text()}, {$demo/csd:name[1]/csd:forename/text()}
	 <a href="{$adapter_link}?oid={$oid}"> Scheduling with Free Busy </a>
	 <div class='description_html'>{page:get_provider_desc($provider,$doc_name)}</div>
       </li>
       }
   </ul>
   
  let $contents :=
    <div class='container'>
      <h3>Search Parameters</h3>
      Speciality Code: {$code}  on {$codingScheme} <br/>
      City: {$city} <br/>
      <h3>Search Results:</h3>
      {$provider_list}
    </div>

  return page:wrapper($contents)


};

declare function page:get_provider_desc($provider,$doc_name) {
   let $csd_doc := csd_dm:open_document($csd_webconf:db,$doc_name) 
   let $demo:= $provider/csd:demographic[1]
   let $names := 
     (
       for $name in  $demo/csd:name
         return functx:trim(concat($name/csd:surname/text(), ", " ,$name/csd:forename/text() ))
       ,for $common_name in $demo/csd:name/csd:commonName
         return functx:trim($common_name/text() )
      )
   let $unique_names :=  distinct-values($names)
   return (
     for $name in $unique_names return  concat($name, ".  ")
     ,for $address in $demo/csd:address
      let $parts := (
	   "Address ("
	   , string($address/@type) 
	   ,") "
	   ,string-join($address/csd:addressLine/text(), ", ")
  	   )
      return if (count($parts) > 1) then concat(functx:trim(string-join($parts)) , ". ") else ()
     ,let $bp:= $demo/csd:contactPoint/csd:codedType[@code="BP"and @codingScheme="urn:ihe:iti:csd:2013:contactPoint"]
       return if ($bp) then ("Business Phone: " , $bp/text() , ".") else ()
     ,for $fac_ref in $provider/csd:facility/@oid
       let $fac := if ($fac_ref) then $csd_doc/csd:facilityDirectory/csd:facility[@oid = $fac_ref]  else ()
       return if ($fac) then ("Duty Post: " , $fac/csd:primaryName/text() , ".") else ()
   )
};









(:Supposed to be linked into header of a web-page, such as the OpenHIE Health Worker Registry Management Interface :)
declare
  %rest:path("/CSD/adapter/zimbra/{$query_name}")
  %rest:GET
  %output:method("xhtml")
  function page:show_searches_on_docs($query_name) 
{ 
  let $analyses := 
      <ul>
        {
  	  for $doc_name in csd_dm:registered_documents($csd_webconf:db)      
	  return
  	  <li>
	  
	    <a href="{$csd_webconf:baseurl}CSD/adapter/zimbra/{$query_name}/{$doc_name}">{string($doc_name)}</a>
	    <br/>

	  </li>
	}
      </ul>

   let $contents :=
      <div class='contatiner'>
	<a href="{$csd_webconf:baseurl}CSD/adapter/zimbra">Zimbra Adapters</a>
        {$analyses}
      </div>
   return page:wrapper($contents)

};


declare function page:get_provider_link($provider,$search_name) 
{
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $function_link := $function/csd:extension[@type='provider_link' and @urn='urn:openhie.org:openinfoman:adapter:zimbra']
  return concat($function_link,$provider/@oid)
};



declare function page:get_freebusy_link($provider,$search_name) 
{
 $provider/csd:demographic/csd:contactPoint[@code="EMAIL" and @codingScheme="urn:ihe:iti:csd:2013:contactPoint"][1]/text()
(:    let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
    let $host := ($function/csd:extension[@type='zimbra_host' and @urn='urn:openhie.org:openinfoman:adapter:zimbra'])[1]
    return concat("http://" , $host ,"/home/" , string($provider/@oid) , "?fmt=ifb") 
:)
};



declare function page:get_email($provider,$search_name) 
{
 $provider/csd:demographic/csd:contactPoint/csd:codedType[@code="EMAIL" and @codingScheme="urn:ihe:iti:csd:2013:contactPoint" ][1]/text()
(:  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $host := ($function/csd:extension[@type='zimbra_host' and @urn='urn:openhie.org:openinfoman:adapter:zimbra'])[1]
  return concat(string($provider/@oid) , '@' , string($host))
:)
};

declare function page:get_email_form($provider,$search_name,$doc_name) {
  page:get_email_form($provider,$search_name,$doc_name,()) 
};

declare function page:get_email_form($provider,$search_name,$doc_name,$svcs) {
 let $mailto := concat("mailto:" ,  page:get_email($provider,$search_name))
 let $text := 
   if (count($svcs) > 0) then
     concat("This is an appointment request for the following service(s): " , string-join(for $svc in $svcs return page:get_service_name($doc_name,$svc),", "))
   else 
     ""
 let $js := concat( 
   "var formattedBody =  'Request Summary: ' + $('#content').val() + " , '"\nAppointment Time: "', "  + $('#datetimepicker_appointment').val() + " , '"\nDuration: "', "  + $('#duration').val(); ",
   "$('#request_form').attr('action','" , $mailto, "?Subject=' + $('#subject').val()+ '&amp;body=' +  encodeURIComponent(formattedBody) ); ",
   "return true;")
 return 
   <div>
     <h2>Send E-Mail Request for Appointment</h2>
     <label for='subject'>Subject:</label>
     <p>
       <input type='text' name='subject' id='subject' value='Scheduling Request'/>
     </p>
     <label for='content'>Request Details:</label>
     <p>
       <textarea id='content'  name='content' rows='6' cols='60'>{$text}</textarea>
     </p>
     <label id='datetime' for='datetime'>Appointment Date and Time:</label>
     <p>
       <input  size="35" id="datetimepicker_appointment"    name='datetime' type="text" />   
     </p>
     <label for='duration'>Duration:</label>
     <p>
       <select id='duration' type='text' name='duration'>
         <option value='15'>15 minutes</option>
         <option value='30'>30 minutes</option>
         <option value='60'>one hour</option>
         <option value='120'>two hours</option>
       </select>
     </p>
     <form action="{$mailto}" method='post' id='request_form'>
       <div class='pull-right'>
	 <input type='submit' onClick="{$js}" value='Submit'/>
       </div>

     </form>
   </div>

};




declare function page:get_invite_form($provider,$search_name,$doc_name,$svcs) {
 let $action := "http://csd.ihris.org/relay_invite.php"
 let $text := 
   if (count($svcs) > 0) then
     concat("This is an appointment request for the following service(s): " , string-join(for $svc in $svcs return page:get_service_name($doc_name,$svc),", "))
   else 
     ""
 return 
   <div>
     <h2>Send Invitation Request for Appointment</h2>
     <form action="{$action}" method='POST' id='request_form'>
       <input type='hidden' name='oid' value='{$provider/@oid}'/>
       <input type='hidden' name='cn' value='{($provider/csd:demographic/csd:name/csd:commonName)[1]}'/>
       <label for='subject'>Subject:</label>
       <p>
	 <input type='text' name='subject' id='subject' value='Scheduling Request'/>
       </p>
       <label for='content'>Request Details:</label>
       <p>
	 <textarea id='content'  name='content' rows='6' cols='60'>{$text}</textarea>
       </p>
       <label id='datetime' for='datetime'>Appointment Date and Time:</label>
       <p>
	 <input  size="35" id="datetimepicker_invite"    name='datetime' type="text" />   
       </p>
       <label for='duration'>Duration:</label>
       <p>
	 <select id='duration' type='text' name='duration'>
           <option value='15'>15 minutes</option>
           <option value='30'>30 minutes</option>
           <option value='60'>one hour</option>
           <option value='120'>two hours</option>
	 </select>
       </p>
       <div class='pull-right'>
	 <input type='submit' value='Submit'/>
       </div>

     </form>
   </div>

};



(:helper method to avoid cross site scripting issues :)
declare
  %rest:path("/CSD/adapter/zimbra/{$query_name}/{$doc_name}/pull_fb/{$provider_oid}/{$fac_oid}/{$svc_oid}")
  %rest:GET
  %output:method("xhtml")
  function page:pull_fb($query_name,$doc_name,$provider_oid,$fac_oid,$svc_oid) 
{
  let $provider := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:providerDirectory/csd:provider[@oid = $provider_oid]
  let $facility := $provider/csd:facilities/csd:facility[@oid = $fac_oid]
  let $service := $facility/csd:service[@oid = $svc_oid]
  let $fb_uri := $service/csd:freeBusyURI[1]/text()
  return if ($fb_uri) 
    then
      let $res := http:send-request(<http:request method="get" href="{$fb_uri}"/>)
      return $res[2]	
    else ()
};




declare function page:free_busy_data($provider,$query_name,$doc_name) {
   page:free_busy_data($provider,$query_name,$doc_name,())
};

declare function page:free_busy_data($provider,$query_name,$doc_name,$svc_oids) 
{
  <div>
    <h1>Facility Based Services</h1>
    {if (count($provider/csd:facilities/csd:facility) = 0) then "This provider is not associated to any facilities" else () }
    <ul>
    {
      for $facility in $provider/csd:facilities/csd:facility
      let $fac_oid := string($facility/@oid)
      let $services := 
	if (count($svc_oids) > 0) 
	  then  $facility/csd:service[@oid = $svc_oids and csd:freeBusyURI]
	  else 	$facility/csd:service[csd:freeBusyURI]


      return
	if (count($services) = 0) 
	  then ()
	else 
	  <li>
	    Facility: {page:get_facility_name($doc_name,$fac_oid)} ({$fac_oid})
	    <br/>
	    <h2>Services</h2>
	    <ul>
	      {
	      for $service in $services
	      let $svc_oid := string($service/@oid)
	      let $svc_name := page:get_service_name($doc_name,$svc_oid)
	      let $cal_url := ($service/csd:extension[@type="calview" and @oid="urn:openhie.org:openinfoman:adapter:zimbra"])[1]/text()
	      let $fb_uri := concat( $csd_webconf:baseurl ,"CSD/adapter/zimbra/" , $query_name, "/" , $doc_name, "/pull_fb/" , string($provider/@oid) , "/" , $fac_oid, "/" , $svc_oid)
	      let $id := replace(concat($svc_oid ,"_at_",$fac_oid),"\.","_")
	      let $data_id := concat("fb_data_",$id)
	      let $req_id := concat("fb_req_",$id)
	      let $link := concat( $csd_webconf:baseurl ,"CSD/adapter/zimbra/" , $query_name, "/" , $doc_name, "/scheduling?oid=" , string($provider/@oid) , "&amp;svc=",  $svc_oid)
	      let $fb_data_js := concat( 
		"$('#", $data_id , "').text('Requesting Data From: ", $fb_uri , "');",
		"$('#",$data_id,"').load('", $fb_uri,"');",
		"return false;"
		)		
	      return
	        <li>
 		  Service: {$svc_name} ({$svc_oid})
		  <br/>
		  <a id="{$req_id}" href="{$fb_uri}" onClick="{$fb_data_js}">View Free Busy Data</a>
		  / <a href="{$link}#email" onClick="$('#tab_email a').tab('show'); 	window.location.hash = 'email';return false;" >Schedule This Service</a> 
		  
		  / <a href="{$link}#invite" onClick="$('#tab_invite a').tab('show'); window.location.hash = 'invite';return false;">Send Invite For This Service</a> 

		  { if ($cal_url) then  ( " / ",  <a target='_id'  href="{$cal_url}">View Calendar</a>) else () }
		  <pre id="{$data_id}"/>
		</li>	    
	       }
	    </ul>
	  </li>
    }
    </ul>
  </div>


};


declare function page:get_facility_name($doc_name,$fac_oid) {
  let $fac := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:facilityDirectory/csd:facility[@oid = $fac_oid]
  return $fac/csd:primaryName/text()

};

declare function page:get_service_name($doc_name,$svc_oid) {
  let $service := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:serviceDirectory/csd:service[@oid = $svc_oid]
  let $code := string($service/csd:codedType/@code)
  let $codeSystem := string($service/csd:codedType/@codingScheme)
  return svs_lsvs:lookup_code($csd_webconf:db,$code,$codeSystem)
};

declare function page:get_schedulable_data($provider,$query_name,$doc_name) {
  page:get_schedulable_data($provider,$query_name,$doc_name,()) 
};

declare function page:get_schedulable_data($provider,$query_name,$doc_name,$svc_oids) 
{
  <div>
    <h1>Facility Based Services</h1>
    {if (count($provider/csd:facilities/csd:facility) = 0) then "This provider is not associated to any facilities" else () }
    <ul>
    {
      for $facility in $provider/csd:facilities/csd:facility
      let $fac_oid := string($facility/@oid)
      let $fac_entity := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:facilityDirectory/csd:facility[@oid = $fac_oid]
      let $services := 
	if (count($svc_oids) > 0) 
	  then  $facility/csd:service[@oid = $svc_oids and csd:freeBusyURI]
	  else 	$facility/csd:service[csd:freeBusyURI]
      let $fac_ohs := $facility/csd:operatingHours
      return
	if (count($services) = 0) 
	  then ("No services found.")
	else 
	  <li>
	    Facility: {page:get_facility_name($doc_name,$fac_oid)} ({$fac_oid})
	    <br/>
	    Facility Operating Hours:
	    {page:show_ohs($fac_ohs)}
	    <h2>Services</h2>
	    <ul>
	      {
	      for $service in $services
	      let $svc_oid := string($service/@oid)
	      let $org_oids := $provider/csd:organizations/csd:organization/@oid
	      let $svc_name := page:get_service_name($doc_name,$svc_oid)
	      let $svc_ohs := $service/csd:operatingHours
	      let $valid_orgs := $fac_entity/csd:organizations/csd:organization[@oid =$org_oids]
	      let $link := concat( $csd_webconf:baseurl ,"CSD/adapter/zimbra/" , $query_name, "/" , $doc_name, "/scheduling?oid=" , string($provider/@oid) , "&amp;svc=",  $svc_oid)
	      return
	        <li>
 		  Service: {$svc_name} ({$svc_oid})
		  <a href="{$link}#email" onClick="$('#tab_email a').tab('show');window.location.hash = 'email';return false;">Schedule</a> 
		  / <a href="{$link}#invite" onClick="$('#tab_email a').tab('show');window.location.hash = 'invite';return false;">Invite</a>
		  <br/>
		  Provider Operating Hours:
		  {page:show_ohs($svc_ohs)}
		  <br/>
		  {
		    if (count($valid_orgs) =  0) 
		      then ("No organizational association for this service.") 
		      else 
			<span>
			  Organization Operating Hours for this service:
			  <ul>
			    {
			      for $org in $valid_orgs
			      let $org_oid := string($org/@oid)
			      let $org_entity := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:organizationDirectory/csd:organization[@oid = $org_oid]
			      let $org_name := $org_entity/csd:primaryName/text()
			      let $org_ohs := $org/csd:service[@oid = $svc_oid]/csd:operatingHours
			      return
				<li> 
				  Organization: {$org_name} ({$org_oid})
				  <br/>
				  {page:show_ohs($org_ohs)}		  
				</li>
			    }
			  </ul>
			</span>
		    }

	  	  </li>	    
	       }
	    </ul>
	  </li>
    }
    </ul>
  </div>
};


declare function page:show_ohs($ohs) 
{
let $dows := map { 0: 'Sunday',1:'Monday',2:'Tuesday',3:'Wednesday',4:'Thursday',5:'Friday',6:'Sunday'}
return
  if (count($ohs) = 0) 
    then "No operating hours defined."
  else 
  <ul>
    {
      for $oh in $ohs
      return 
      <li>
      Days Of The Week: {
	let $text_dows := for $dow in $oh/csd:dayOfTheWeek return map:get($dows,xs:int($dow))
	return string-join($text_dows,", ")
      }
      <br/>
      Hours of Operation: {$oh/csd:beginningHour/text()} - {$oh/csd:endingHour/text()}
      </li>
    }
  </ul>
};

declare
  %rest:path("/CSD/adapter/zimbra/{$query_name}/{$doc_name}/scheduling")
  %rest:GET
  %output:method("xhtml")
  %rest:query-param("oid", "{$oid}")
  %rest:query-param("svc", "{$svc}")
  function page:show_results($query_name,$doc_name,$oid,$svc)
{ 
let $provider := csd_dm:open_document($csd_webconf:db,$doc_name)/csd:CSD/csd:providerDirectory/csd:provider[@oid = $oid]
let $svcs := if ($svc) then ($svc) else ()
let $fb_tab :=  page:free_busy_data($provider,$query_name,$doc_name,$svcs)
let $schedulable_tab := page:get_schedulable_data($provider,$query_name,$doc_name,$svcs)
let $full_tab := 
 <div class='container'>
   <p>
     <a target="_full_record" href="{page:get_provider_link($provider,$query_name)}">View Full Record</a>
     in the Health Worker Registry Management Interface
   </p>
   <p>
     Interface is based on <a href='http://www.ihris.org'>iHRIS Platform</a> and the <a href='https://github.com/openhie/openinfoman-hwr'>OpenInfoMan Health Worker Registry Library</a>
   </p>
   
 </div>
let $email_tab := page:get_email_form($provider,$query_name,$doc_name,$svcs)
let $invite_tab := page:get_invite_form($provider,$query_name,$doc_name,$svcs)
return page:wrapper_tabs($provider,$doc_name,$fb_tab,$schedulable_tab,$full_tab,$email_tab,$invite_tab)
};






declare function page:wrapper_tabs($provider,$doc_name,$fb_tab,$schedulable_tab,$full_tab,$email_tab,$invite_tab) {
 <html >
  <head>

    <link href="{$csd_webconf:baseurl}static/bootstrap/css/bootstrap.css" rel="stylesheet"/>
    <link href="{$csd_webconf:baseurl}static/bootstrap/css/bootstrap-theme.css" rel="stylesheet"/>

    <link rel="stylesheet" type="text/css" media="screen"   href="{$csd_webconf:baseurl}static/bootstrap/js/tab.js"/>    

    <link rel="stylesheet" type="text/css" media="screen"   href="{$csd_webconf:baseurl}static/bootstrap-datetimepicker/css/bootstrap-datetimepicker.min.css"/>

    <script src="https://code.jquery.com/jquery.js"/>
    <script src="{$csd_webconf:baseurl}static/bootstrap-datetimepicker/js/bootstrap-datetimepicker.js"/>
    <script src="{$csd_webconf:baseurl}static/bootstrap/js/bootstrap.min.js"/>
   <script type="text/javascript">
    $( document ).ready(function() {{
      $('#tab_fb a').click(function (e) {{
	e.preventDefault()
	window.location.hash = e.target.hash;
	$(this).tab('show')
      }});
      $('#tab_schedulable a').click(function (e) {{
	e.preventDefault()
	window.location.hash = e.target.hash;
	$(this).tab('show')
      }});
      $('#tab_full a').click(function (e) {{
	e.preventDefault()
	window.location.hash = e.target.hash;
	$(this).tab('show')
      }});
      $('#tab_email a').click(function (e) {{
	e.preventDefault()
	window.location.hash = e.target.hash;
	$(this).tab('show')
      }});
      $('#tab_invite a').click(function (e) {{
	e.preventDefault()
	window.location.hash = e.target.hash;
	$(this).tab('show')
      }});



if (url.match('#')) {{
    $('#tab_' + url.split('#')[1] + ' a' ).tab('show') ;
}} 

// Change hash for page-reload
//$('.nav-tabs a').on('shown', function (e) {{
//    
//}})
    }});
   </script>
    <script type="text/javascript">
    $( document ).ready(function() {{        
     $('#datetimepicker_appointment').datetimepicker({{format: 'yyyy-mm-ddThh:ii:ss+00:00',startDate:'2013-10-01'}});
     $('#datetimepicker_invite').datetimepicker({{format: 'yyyy-mm-ddThh:ii:ss+00:00',startDate:'2013-10-01'}});
    }});
    </script>
  </head>
  <body>  
    <div class="navbar navbar-inverse navbar-static-top">
      <div class="container">
	<img class='pull-left' height='38px' src='http://upload.wikimedia.org/wikipedia/commons/7/74/GeoGebra_icon_geogebra.png'/>
        <div class="navbar-header">
          <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="{$csd_webconf:baseurl}CSD">OpenInfoMan</a>
        </div>
	<img  class='pull-right' src='http://ohie.org/wp-content/uploads/2013/02/openhie-logo.png' style='height:3.5em'/>
      </div>
    </div>
    <div class="container">

      <div class="tab-content panel">
	<ul class="nav nav-tabs">
	  <li id='tab_fb' class="active"><a  href="#fb">Free Busy Data</a></li>
	  <li id='tab_schedulable'><a  href="#schedulable">Operating Hours</a></li>
	  <li id='tab_full'><a  href="#full">Full Record</a></li>
	  <li id='tab_email'><a  href="#email" >Email Appt. Request</a></li>
	  <li id='tab_invite'><a  href="#invite">Send Invite</a></li>
	</ul>
	<div class='container'>
	  <div class="text-success">
	  {page:get_provider_desc($provider,$doc_name)}
	  </div>
	</div>
	<div class="tab-pane active panel-body" id="fb">{$fb_tab}</div>
	<div class="tab-pane panel-body" id="schedulable">{$schedulable_tab}</div>
	<div class="tab-pane panel-body" id="full">{$full_tab}</div>
	<div class="tab-pane panel-body" id="email">{$email_tab}</div>
	<div class="tab-pane panel-body" id="invite">{$invite_tab}</div>
      </div>
    </div>
    <center>
     
     <img src="{$csd_webconf:baseurl}static/USAID_CP_IH_logos.png" width='70%'/>
    </center>

  </body>
 </html>
};





declare function page:wrapper($content) {
 <html >
  <head>

    <link href="{$csd_webconf:baseurl}static/bootstrap/css/bootstrap.css" rel="stylesheet"/>
    <link href="{$csd_webconf:baseurl}static/bootstrap/css/bootstrap-theme.css" rel="stylesheet"/>
    

    <script src="https://code.jquery.com/jquery.js"/>
    <script src="{$csd_webconf:baseurl}static/bootstrap/js/bootstrap.min.js"/>
  </head>
  <body>  
    <div class="navbar navbar-inverse navbar-static-top">
      <div class="container">
	<img class='pull-left' height='38px' src='http://upload.wikimedia.org/wikipedia/commons/7/74/GeoGebra_icon_geogebra.png'/>
        <div class="navbar-header">
          <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="{$csd_webconf:baseurl}CSD">OpenInfoMan</a>
        </div>
	<img  class='pull-right' src='http://ohie.org/wp-content/uploads/2013/02/openhie-logo.png' style='height:3.5em'/>
      </div>
    </div>
    <div class='container'> {$content}</div>
    <center>
     
     <img src="{$csd_webconf:baseurl}static/USAID_CP_IH_logos.png" width='70%'/>
    </center>

  </body>
 </html>
};


