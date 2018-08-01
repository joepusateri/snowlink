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
use Text::CSV;

my(%opts);
my(@opts)=('pagerduty_token|p=s',
           'filename|f=s',
           'help|h',
           'debug|d'
    );

die unless GetOptions(\%opts,@opts);

if(!%opts || $opts{help}){
  print <<EOT;
$0: get relevant keys for ServiceNow Extensions

options:

 --pagerduty_token | -p <V2 API token>
 --file | f <filename>
 --help | -h (this message)
 --debug | -d
EOT
exit 0;
}

die "--pagerduty_token|-p required" unless($opts{pagerduty_token});
die "--filename|-f required" unless($opts{filename});

#faked inputs
my($j, $cmd);
my(%int_version);
$int_version{'v4'} = "P6MB86H";
$int_version{'v5'} = "PAD6MYW";

sub getService {
  my($service_target) = @_;
  my(%service);
  $service{'serviceid'} = "";
  $service{'epid'} = "";
  # retrieve specified service
  $cmd = "curl -s -H 'Authorization: Token token=$opts{pagerduty_token}' " .
      "'https://api.pagerduty.com/services?query=@{[uri_escape($service_target)]}'";
  print "$cmd\n" if($opts{debug});
  $j = scalar(`$cmd`);
  my($as) = from_json($j, {allow_nonref=>1});
  print "$j\n" if($opts{debug});
  for(@{$as->{services}}){
    $service{'serviceid'} = $_->{id};
    $service{'epid'} = $_->{escalation_policy}{id};
    last;
  }
  return %service;
}

sub findExistingExtension {
  my($snow_url_target, $snow_service_target, $int_version_key) = @_;
  print "Looking for: $snow_url_target $snow_service_target\n" if($opts{debug});
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
      print "Testing: $name $snow_user $snow_version $snow_url $snow_service\n" if($opts{debug});
      if ($snow_version eq $int_version{$int_version_key} && $snow_url eq $snow_url_target && $snow_service eq $snow_service_target)
      {
        print "compare succeeded\n" if($opts{debug});
        $found_extension = $_;
        last;
      }
    }
  }
  return $found_extension;
}


sub createExtension {
  my($snow_instance, $snow_api_user, $snow_api_pw, $sync, $int_version_key, %service) = @_;
  # create extension
  print "Creating extension $int_version_key\n" if($opts{debug});
  my($body) = {
    'extension' => {
      'name' => "ServiceNow ($snow_instance)",
      'config' => {
        "snow_user" =>  $snow_api_user,
        "snow_password" =>  $snow_api_pw,
        "sync_options" =>  ($sync eq "auto" ? "sync_all" : "manual_sync"),
        "target"=> "https://$snow_instance.service-now.com/api/x_pd_integration/pagerduty2sn"
      },
      "extension_schema" => {
        "id" => $int_version{$int_version_key},
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
  print "Sending: $jsonbody\n" if($opts{debug});

  $cmd = "curl -s -H 'Authorization: Token token=$opts{pagerduty_token}' " .
      "-H 'Content-type: application/json' -X POST " .
      "-d '$jsonbody'" .
      " 'https://api.pagerduty.com/extensions'";
  print "$cmd\n" if($opts{debug});
  $j = scalar(`$cmd`);
  my($ext_create) = from_json($j, {allow_nonref=>1});
  my($found_webhook_id) = $ext_create->{extension}{id};
  print "$j\n" if($opts{debug});
  print "Created $service{'serviceid'} $service{'epid'} $found_webhook_id\n" if($opts{debug});
  return $found_webhook_id;
}

sub updateAssignmentGroup {
  my($snow_update_user, $snow_update_password, $snow_assignment_group_name, $snow_instance, $webhook_id, %service) = @_;
  print "Updating Assignment Group $snow_assignment_group_name\n" if($opts{debug});
  #get sys_id for SN Assignment Group
  # $cmd = "curl -s -H 'Authorization: basic cGFnZXJkdXR5LWludDpQYWdlckR1dHk=' " .
  $cmd = "curl -s -u $snow_update_user:$snow_update_password " .
      "-H 'Accept: application/json' " .
      "'https://$snow_instance.service-now.com/api/now/table/sys_user_group?sysparm_query=name=@{[uri_escape($snow_assignment_group_name)]}'";
  print "$cmd\n" if($opts{debug});
  $j = scalar(`$cmd`);
  my($sag) = from_json($j, {allow_nonref=>1});
  my($snow_ag_id) = $sag->{result}[0]{sys_id};

  if ($snow_ag_id)
  {
    #push SN Assignment Group update
    print "Found Group\n" if($opts{debug});
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
    print "$cmd\n" if($opts{debug});
    $j = scalar(`$cmd`);
    my($sag_update) = from_json($j, {allow_nonref=>1});
    print "$j\n" if($opts{debug});
    print "Successfully updated $snow_assignment_group_name\n";
  }
  else
  {
    print "Unable to find Assignment Group $snow_assignment_group_name\n";
  }
}
#my($parm_snow_instance) = "dev52132";
#my($parm_snow_api_user) = "pagerduty-int";
#my($parm_snow_api_pw) = "PagerDuty";
#my($parm_snow_update_user) = "pagerduty-int";
#my($parm_snow_update_pw) = "PagerDuty";

#y($parm_service_target) = "AddResponderCallout";
#my($parm_snow_assignment_group_name) = "Change Management";
my $csv = Text::CSV->new({ sep_char => ',' });

my $file = $opts{filename};
print "file is $file\n";

open(my $data, '<', $file) or die "Could not open '$file' $!\n";
while (my $line = <$data>) {
  chomp $line;

  if ($csv->parse($line)) {

      my @fields = $csv->fields();
      print("Read line: $fields[0], $fields[1], $fields[2], $fields[3], $fields[4], $fields[5], $fields[6], $fields[7], $fields[8]\n") if($opts{debug});
      pair($fields[0], $fields[1], $fields[2], $fields[3], $fields[4], $fields[5], $fields[6], $fields[7], $fields[8]);

  } else {
      warn "Line could not be parsed: $line\n";
  }
}

sub pair {
  my($parm_snow_instance, $parm_snow_api_user, $parm_snow_api_pw,
     $parm_snow_update_user, $parm_snow_update_pw, $parm_service_target,
     $parm_snow_assignment_group_name, $parm_sync, $int_version_key)=@_;
  #get hash with service id and escalation policy id
  my($snow_url_target) = "https://$parm_snow_instance.service-now.com/api/x_pd_integration/pagerduty2sn";
  my(%service) = getService($parm_service_target);
  print "serviceid=$service{'serviceid'}\n" if($opts{debug});
  print "epid     =$service{'epid'}\n" if($opts{debug});

  if ($service{'serviceid'} eq "")
  {
    print "Service ID not found for $parm_service_target. Skipping...\n";
    last;
  }
  #using service id, find if PD has an extension already
  my($found_extension) = findExistingExtension($snow_url_target, $service{'serviceid'}, $int_version_key);

  my($found_webhook_id);

  # if found, get webhook id
  if ($found_extension)
  {
    $found_webhook_id = $found_extension->{id};
    print "Found ServiceNow Extension for $parm_service_target ($service{'serviceid'} $service{'epid'} $found_webhook_id)\n";
  }
  else
  {
    $found_webhook_id = createExtension($parm_snow_instance, $parm_snow_api_user, $parm_snow_api_pw, $parm_sync, $int_version_key, %service);
    print "Created ServiceNow Extension for $parm_service_target ($service{'serviceid'} $service{'epid'} $found_webhook_id)\n";
  }

  #update SNOW with values
  updateAssignmentGroup($parm_snow_update_user, $parm_snow_update_pw, $parm_snow_assignment_group_name, $parm_snow_instance, $found_webhook_id, %service);
}
