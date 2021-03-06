#!/bin/sh -
#

# FLASK

set -e

awk=$1
shift

# output files
av_permissions="include/av_permissions.h"
av_perm_to_string="include/av_perm_to_string.h"

cat $* | $awk "
BEGIN	{
		outfile = \"$av_permissions\"
		avpermfile = \"$av_perm_to_string\"
		"'
		nextstate = "COMMON_OR_AV";
		printf("/* This file is automatically generated.  Do not edit. */\n") > outfile;
		printf("/* This file is automatically generated.  Do not edit. */\n") > avpermfile;
;
	}
/^[ \t]*#/	{ 
			next;
		}
$1 == "class"	{
			if (nextstate != "COMMON_OR_AV" &&
			    nextstate != "CLASS_OR_CLASS-OPENBRACKET")
			{
				printf("Parse error:  Unexpected class definition on line %d\n", NR);
				next;	
			}

			tclass = $2;

			if (tclass in av_defined)
			{
				printf("Duplicate access vector definition for %s on line %d\n", tclass, NR);
				next;
			} 
			av_defined[tclass] = 1;

			permission = 0;

			nextstate = "INHERITS_OR_CLASS-OPENBRACKET";
			next;
		}
$1 == "{"	{ 
			if (nextstate != "INHERITS_OR_CLASS-OPENBRACKET" &&
			    nextstate != "CLASS_OR_CLASS-OPENBRACKET" &&
			    nextstate != "COMMON-OPENBRACKET")
			{
				printf("Parse error:  Unexpected { on line %d\n", NR);
				next;
			}

			if (nextstate == "INHERITS_OR_CLASS-OPENBRACKET")
				nextstate = "CLASS-CLOSEBRACKET";

			if (nextstate == "CLASS_OR_CLASS-OPENBRACKET")
				nextstate = "CLASS-CLOSEBRACKET";

			if (nextstate == "COMMON-OPENBRACKET")
				nextstate = "COMMON-CLOSEBRACKET";
		}
/[a-z][a-z_]*/	{
			if (nextstate != "COMMON-CLOSEBRACKET" &&
			    nextstate != "CLASS-CLOSEBRACKET")
			{
				printf("Parse error:  Unexpected symbol %s on line %d\n", $1, NR);		
				next;
			}

			if (nextstate == "COMMON-CLOSEBRACKET")
			{
				if ((common_name,$1) in common_perms)
				{
					printf("Duplicate permission %s for common %s on line %d.\n", $1, common_name, NR);
					next;
				}

				common_perms[common_name,$1] = permission;

				printf("#define COMMON_%s__%s", toupper(common_name), toupper($1)) > outfile; 

				printf("    S_(\"%s\")\n", $1) > cpermfile;
			}
			else
			{
				if ((tclass,$1) in av_perms)
				{
					printf("Duplicate permission %s for %s on line %d.\n", $1, tclass, NR);
					next;
				}

				av_perms[tclass,$1] = permission;
		
				printf("#define %s__%s", toupper(tclass), toupper($1)) > outfile; 

				printf("   S_(SECCLASS_%s, %s__%s, \"%s\")\n", toupper(tclass), toupper(tclass), toupper($1), $1) > avpermfile; 
			}

			spaces = 40 - (length($1) + length(tclass));
			if (spaces < 1)
			      spaces = 1;

			for (i = 0; i < spaces; i++) 
				printf(" ") > outfile; 
			printf("(1UL << %u)\n", permission) > outfile;
			permission = permission + 1;
		}
$1 == "}"	{
			if (nextstate != "CLASS-CLOSEBRACKET" && 
			    nextstate != "COMMON-CLOSEBRACKET")
			{
				printf("Parse error:  Unexpected } on line %d\n", NR);
				next;
			}

			if (nextstate == "COMMON-CLOSEBRACKET")
			{
				common_base[common_name] = permission;
				printf("TE_(common_%s_perm_to_string)\n\n", common_name) > cpermfile; 
			}

			printf("\n") > outfile;

			nextstate = "COMMON_OR_AV";
		}
END	{
		if (nextstate != "COMMON_OR_AV" && nextstate != "CLASS_OR_CLASS-OPENBRACKET")
			printf("Parse error:  Unexpected end of file\n");

	}'

# FLASK
