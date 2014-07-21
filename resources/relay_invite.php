<html>
<body>
<?php
echo "Received Data:<pre>" . print_r($_POST,true) . "</pre>";
$to = $_POST['oid'] . '@ec2-54-216-82-154.eu-west-1.compute.amazonaws.com';
$subject = $_POST['subject'];
$cn = $_POST['cn'];
$content = $_POST['content'];
$start = $_POST['datetime'];
$duration =  $_POST['duration'];
//see http://blog.sebastian-martens.de/2012/01/submit-outlook-calendar-invitations-with-php/
//see http://webcheatsheet.com/php/send_email_text_html_attachment.php#attachment

$random_hash = md5(date('r', time())); 

$start_dt = new DateTime($start);
$end_dt = new DateTime($start);
$now_dt = new DateTime();
date_modify($end_dt,"+ " . $duration . " minute");

$start_dt = date_format($start_dt,"Ymd") . "T" . date_format($start_dt,"His") . "Z";
$end_dt = date_format($end_dt,"Ymd") . "T" . date_format($end_dt,"His") . "Z";
$now_dt = date_format($now_dt,"Ymd") . "T" . date_format($now_dt,"His") . "Z";

$invite = "BEGIN:VCALENDAR
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:REQUEST
BEGIN:VEVENT
UID:{$random_hash}@csd.ihris.org
DTSTART:{$start_dt}
DTEND:{$end_dt}
DTSTAMP:{$now_dt}
ORGANIZER;CN=Anonymous:mailto:relay@csd.ihris.org
ATTENDEE;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN={$cn};X-NUM-GUESTS=0:mailto:{$to}
CREATED:
DESCRIPTION:{$content}
LAST-MODIFIED:{$now_dt}
SUMMARY:{$subject}
SEQUENCE:0
STATUS:NEEDS-ACTION
TRANSP:OPAQUE
END:VEVENT
END:VCALENDAR
";

echo "<br/>Created Invite:<pre>" . $invite . "</pre>";


$headers .= "MIME-version: 1.0\r\n";
$headers .= "Content-class: urn:content-classes:calendarmessage\r\n";
$headers .= "Content-type: text/calendar; method=REQUEST; charset=UTF-8\r\n";

$message = $invite;


if ($res = @mail($to,$subject,$message,$headers)) {
    echo "Invitation Sent!";
} else {
    echo "Failed!";
}

?>




</body>
</html>