awsdot - Visualise multiple AWS Cloudformation stacks using graphviz
====================================================================

Summary
-------

awsdot processes multiple AWS Cloudformation stacks, looking for "actors" (IAM
users and roles), and trying to work out how they might interact with each
other by seeing what resources they have in common.

It does this by reading the IAM policies (as defined in the stacks'
templates), looking to see what resources the user or role has permission to
interact with.

It doesn't query the account "live" (i.e. doesn't make AWS API calls) -
instead, it depends on reading local json files which contain dumps of the
stacks that you want to analyse.

BBC-specific behaviour, and other limitations
---------------------------------------------

It's currently somewhat BBC specific, mostly to do with our naming
conventions.  Search the code for "FIXME" to find these references, so you can
remove or customise them.

It may not work well across multiple accounts, or multiple regions.

It's tailored to understand the stacks the way we use them at the BBC.  YMMV.

