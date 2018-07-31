#!/usr/bin/perl

######################################################################
# script to print service, escalation policy and webhook keys for
# any PD domain
######################################################################

######################################################################
#Permission is hereby granted, free of charge, to any person
#obtaining a copy of this software and associated documentation
#files (the "Software"), to deal in the Software without
#restriction, including without limitation the rights to use,
#copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the
#Software is furnished to do so, subject to the following
#conditions:
#
#The above copyright notice and this permission notice shall be
#included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#OTHER DEALINGS IN THE SOFTWARE.
######################################################################

use Getopt::Long;
use JSON;
use Data::Dumper;
use URI::Escape;
use strict;

my(%opts);
my(@opts)=('pagerduty_token|p=s',
           'help|h',
    );

die unless GetOptions(\%opts,@opts);

if(!%opts || $opts{help}){
  print <<EOT;
$0: get relevant keys for ServiceNow Extensions

options:

 --pagerduty_token | -p <V2 API token>
 --help | -h (this message)
EOT
exit 0;
}

die "--pagerduty_token|-p required" unless($opts{pagerduty_token});

#faked inputs
my($parm_snow_instance) = "dev52132";
my($parm_snow_url_target) = "https://$parm_snow_instance.service-now.com/api/x_pd_integration/pagerduty2sn";
my($parm_snow_api_user) = "pagerduty-int";
my($parm_snow_api_pw) = "PagerDuty";
my($parm_snow_update_user) = "pagerduty-int";
my($parm_snow_update_pw) = "PagerDuty";

my($parm_service_target) = "AddResponderCallout";
my($parm_snow_assignment_group_name) = "Change Management";

my($j, $cmd);

sub getService {
  my($service_target) = @_;
  my(%service);
  # retrieve specified service
  $cmd = "curl -s -H 'Authorization: Token token=$opts{pagerduty_token}' " .
      "'https://api.pagerduty.com/services?query=@{[uri_escape($service_target)]}'";
  print "$cmd\n" if($opts{debug});
  $j = scalar(`$cmd`);
  my($as) = from_json($j, {allow_nonref=>1});

  for(@{$as->{services}}){
    $service{'serviceid'} = $_->{id};
    $service{'epid'} = $_->{escalation_policy}{id};
    last;
  }
  return %service;

}

sub findExistingExtension {
  my($snow_url_target, $snow_service_target) = @_;
  print "Looking for: $snow_url_target $snow_service_target\n";
  # look for a service that matches inputs
  my ($found_extension);
  $cmd = "curl -s -H 'Authorization: Token token=$opts{pagerduty_token}' " .
      "'https://api.pagerduty.com/extensions?limit=100'";
  print "$cmd\n" if($opts{debug});
  $j = scalar(`$cmd`);
  my($e) = from_json($j, {allow_nonref=>1});
  for(@{$e->{extensions}}){
    my($name) = $_->{name};
    my($snow_user) = $_->{config}{snow_user};
    if ($snow_user)
    {
      my($snow_version) = $_->{extension_schema}{id};
      my($snow_service) = $_->{extension_objects}[0]{id};
      my($snow_url) = $_->{config}{target};
      print "$name $snow_user $snow_version $snow_url $snow_service\n";
      if ($snow_version eq 'P6MB86H' && $snow_url eq $snow_url_target && $snow_service eq $snow_service_target)
      {
        print "compare succeeded\n";
        $found_extension = $_;
        last;
      }
    }
  }
  return $found_extension;
}


sub createExtension {
  my($snow_instance, $snow_api_user, $snow_api_pw, %service) = @_;
  # create extension
  print "creating extension\n";
  my($body) = {
    'extension' => {
      'name' => "ServiceNow ($snow_instance)",
      'config' => {
        "snow_user" =>  $snow_api_user,
        "snow_password" =>  $snow_api_pw,
        "sync_options" =>  "manual_sync",
        "target"=> "https://$snow_instance.service-now.com/api/x_pd_integration/pagerduty2sn"
      },
      "extension_schema" => {
        "id" => "P6MB86H",
        "type" => "extension_schema_reference"
      },
      "extension_objects" => [
        {
          "id" => "$service{'serviceid'}",
          "type" => "service_reference",
        }
      ]
    }
  };
  my $jsonbody = to_json $body;
  print "JSON=$jsonbody\n";

  $cmd = "curl -s -H 'Authorization: Token token=$opts{pagerduty_token}' " .
      "-H 'Content-type: application/json' -X POST " .
      "-d '$jsonbody'" .
      " 'https://api.pagerduty.com/extensions'";
  print "$cmd\n";
  $j = scalar(`$cmd`);
  my($ext_create) = from_json($j, {allow_nonref=>1});
  my($found_webhook_id) = $ext_create->{extension}{id};
  print "\n$j\n";
  print "create: found $service{'serviceid'} $service{'epid'} $found_webhook_id\n\n";
  return $found_webhook_id;
}

sub updateAssignmentGroup {
  my($snow_update_user, $snow_update_password, $snow_assignment_group_name, $snow_instance, $webhook_id, %service) = @_;
  print "Updating Assignment Group $snow_assignment_group_name $webhook_id\n";
  #get sys_id for SN Assignment Group
  # $cmd = "curl -s -H 'Authorization: basic cGFnZXJkdXR5LWludDpQYWdlckR1dHk=' " .
  $cmd = "curl -s -u $snow_update_user:$snow_update_password " .
      "-H 'Accept: application/json' " .
      "'https://$snow_instance.service-now.com/api/now/table/sys_user_group?sysparm_query=name=@{[uri_escape($snow_assignment_group_name)]}'";
  print "$cmd\n";
  $j = scalar(`$cmd`);
  my($sag) = from_json($j, {allow_nonref=>1});
  my($snow_ag_id) = $sag->{result}[0]{sys_id};

  if ($snow_ag_id)
  {
    #push SN Assignment Group update

    my($snow_ag_body) = {
      "x_pd_integration_pagerduty_webhook" => $webhook_id,
      "x_pd_integration_pagerduty_escalation" => $service{'epid'},
      "x_pd_integration_pagerduty_service" => $service{'serviceid'}
    };
    my($jsonbody) = to_json $snow_ag_body;
    $cmd = "curl -s -u $snow_update_user:$snow_update_password " .
        "-H 'Accept: application/json' -X PUT " .
        "-H 'Content-Type: application/json' " .
        "-d '$jsonbody' " .
        "'https://$snow_instance.service-now.com/api/now/table/sys_user_group/$snow_ag_id'";
    print "$cmd\n";
    $j = scalar(`$cmd`);
    my($sag_update) = from_json($j, {allow_nonref=>1});
    print "$j\n";
  }
  else
  {
    print "Unable to find Assignment Group $snow_assignment_group_name\n";
  }
}

#get hash with service id and escalation policy id
my(%service) = getService($parm_service_target);
print "serviceid=$service{'serviceid'}\n";
print "epid=$service{'epid'}\n";

#using service id, find if PD has an extension already
my($found_extension) = findExistingExtension($parm_snow_url_target, $service{'serviceid'});

my($found_webhook_id);

# if found, get webhook id
if ($found_extension)
{
  $found_webhook_id = $found_extension->{id};
  print "found $service{'serviceid'} $service{'epid'} $found_webhook_id\n\n";
}
else
{
  $found_webhook_id = createExtension($parm_snow_instance, $parm_snow_api_user, $parm_snow_api_pw, %service);

}

#update SNOW with values
updateAssignmentGroup($parm_snow_update_user, $parm_snow_update_pw, $parm_snow_assignment_group_name, $parm_snow_instance, $found_webhook_id, %service);
