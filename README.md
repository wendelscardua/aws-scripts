# aws-scripts

Some helpful ruby scripts for AWS stuff

## aws-mfa.rb

Adds (or updates) temporary mfa credentials to your `.aws/credentials` file.

Usage:

```sh
$ ruby aws-mfa.rb [--arn-name|-n <arn-name>] [--duration|-d <seconds>] [--no-confirm|-Y] [--token|-t <otp-code>]
```

This will use your current credentials (usually from default profile, but you can change
this via AWS_PROFILE environment variable) to fetch your current user id, aws account and
arn. These will be shown for confirmation.

Then, you'll be asked for the serial number of your MFA. By default, it'll assume it's a
virtual one, named after your user arn (for example, if the user arn is
`arn:aws:iam::1234567890:user/username` the default MFA arn will be
`arn:aws:iam::1234567890:mfa/username`).

After that you'll be asked for the duration (in seconds) for these credentials. The minimum
value is 900 (= 15 minutes).

Finally you'll be asked for the MFA code itself.

The script will parse or create an `.aws/credentials` file in your home directory, then it'll add
(or update) an `[mfa]` section with the temporary credentials to it... and that's it. Now you can
simply use the `mfa` profile when using AWS CLI and other scripts. Remember to set any `.aws/config`
options for the `[mfa]` section as well if needed (e.g. `region`).

Arguments:

- `--duration <seconds>` / `-d <seconds>`: the desired duration in seconds, at
  least 900. Using this will prevent the script from asking it.

- `--arn-name <arn-name>` / `-n <arn-name>`: use this in case your MFA arn is
  not named after your username. For example, if your user arn is
  `arn:aws:iam::1234567890:user/username` but your actual MFA arn is
  `arn:aws:iam::1234567890:mfa/authy`, pass `--arn-name authy`. You still will
  be prompted for confirmation of the entire arn unless `--no-confirm` is also
  used.

- `--no-confirm` / `-Y`: use this to skip arn confirmation.

- `--token <otp-code>` / `-t <otp-code>`: the OTP token code for MFA
  authentication. Using this will prevent the script from asking it.

## update-ip.rb

Updates your public IP on a security group. Assumes all your entries have the same description (e.g. `usename-public-ip`).

Usage:

```sh
ruby update-ip.rb --description <description> --sg <sg-name> [--ip <ip>]
```

Arguments:

- `--description <description>` / `-d <description>`: the description (that is,
  the name, really) of entries to replace in the security group with the new IP.
  This is required.

- `--sg <sg-name`: the name of the security group. This is required.

- `--ip` the new IP to set the entries. This is optional: if not specified, the
  script will query `api.ipify.org` for the IP associated to your box.
