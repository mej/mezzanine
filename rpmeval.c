#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <rpm/rpmcli.h>
#include <rpm/rpmmacro.h>

static char * myRpmExpand(const char *arg, ...)
{
    const char *s;
    char *t, *te;
    size_t sn, tn;
    size_t un = 16 * BUFSIZ;

    va_list ap;

    if (arg == NULL)
	return strdup("");

    t = malloc(strlen(arg) + un + 1);
    *t = '\0';
    te = stpcpy(t, arg);

    va_start(ap, arg);
    while ((s = va_arg(ap, const char *)) != NULL) {
	sn = strlen(s);
	tn = (te - t);
	t = realloc(t, tn + sn + un + 1);
	te = t + tn;
	te = stpcpy(te, s);
    }
    va_end(ap);

    *te = '\0';
    tn = (te - t);
    (void) expandMacros(NULL, NULL, t, tn + un + 1);
    t[tn + un] = '\0';
    t = realloc(t, strlen(t) + 1);
    
    return t;
}

static struct poptOption optionsTable[] = {
   POPT_AUTOALIAS
   POPT_AUTOHELP
   POPT_TABLEEND
};

int main(int argc, char *argv[])
{
    poptContext optCon = rpmcliInit(argc, argv, optionsTable);
    const char ** av;

    if (optCon == NULL)
        exit(EXIT_FAILURE);

    av = poptGetArgs(optCon);

    printf("%s", myRpmExpand(av[0], NULL));

    optCon = rpmcliFini(optCon);

    return 0;
}
