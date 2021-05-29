# aws-scripts
Some helpful ruby scripts for AWS stuff

## aws-mfa.rb

Adds (or updates) temporary mfa credentials to your `.aws/credentials` file.

Usage:

```sh
$ ruby aws-mfa.rb
```

This will use your current credentials (usually from default profile, but you can change
this via AWS_PROFILE environment variable) to fetch your current user id, aws account and
arn. These will be shown for confirmation.

Then, you'll be asked for the serial number of your MFA. By default, it'll assume it's a
virtual one, named after your arn (for example, if the user arn is
`arn:aws:iam::1234567890:user/username` the default mfa arn will be
`arn:aws:iam::1234567890:mfa/username`).

After that you'll be asked for the duration (in seconds) for these credentials. The minimum
value is 900 (= 15 minutes).

Finally you'll be asked for the MFA code itself.

The script will parse or create an `.aws/credentials` file in your home directory, then it'll add
(or update) an `[mfa]` section with the temporary credentials to it... and that's it. Now you can
simply use the `mfa` profile when using AWS CLI and other scripts. Remember to set any `.aws/config`
options for the `[mfa]` section as well if needed (e.g. `region`).

## update-ip.rb

Updates your public IP on a security group. Assumes the security group is used for 22, 80 and 443 ports,
and all your entries have the same description (e.g. `usename-public-ip`).

Usage:

```sh
ruby update-ip.rb security-group-name your-ip-description
```
