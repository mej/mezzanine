#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdint.h>
#include <rpm/rpmio.h>
#include <rpm/rpmcli.h>
#include <rpm/rpmmacro.h>
#include <rpm/rpmts.h>
#include <rpm/rpmlog.h>
#ifdef HAVE_RPM_RPMLEGACY_H
#  define _RPM_4_4_COMPAT
#  include <rpm/rpmlegacy.h>
#endif

static struct poptOption optionsTable[] = {
   POPT_AUTOALIAS
   POPT_AUTOHELP
   POPT_TABLEEND
};

static char *
rpm_get_version(const char *rpmfile)
{
    FD_t fd;
    rpmRC rc;
    Header hdr;
    rpmts ts = NULL;
    char *tmp = NULL;

    if (rpmfile) {
        /* Attempt to pull version and release from RPM file */
        fd = Fopen(rpmfile, "r.ufdio");
        if (fd) {
            if (!Ferror(fd)) {
                if (!ts) {
                    ts = rpmtsCreate();
                }
                rc = rpmReadPackageFile(ts, fd, rpmfile, &hdr);
                if (rc != RPMRC_NOTFOUND && rc != RPMRC_FAIL) {
                    tmp = headerSprintf(hdr, "%{VERSION}-%{RELEASE}", NULL, NULL, NULL);
                    hdr = headerFree(hdr);
                }
            }
            Fclose(fd);
            if (tmp) {
                return tmp;
            }
        }

        /* Failing that, try to parse the RPM name for them. */
        tmp = (char *) rpmfile + strlen(rpmfile) - 4;
        if (!strcasecmp(tmp, ".rpm")) {
            char *newfile = strdup(rpmfile);

            /* Kill .rpm suffix */
            tmp = (char *) newfile + strlen(newfile) - 4;
            *tmp = 0;
            /* Kill .arch portion */
            tmp = strrchr(newfile, '.');
            if (tmp) *tmp = 0;
            /* Temporarily kill release string */
            tmp = strrchr(newfile, '-');
            if (tmp) *tmp = 0;
            /* Look for version string. */
            rpmfile = strrchr(newfile, '-');
            if (rpmfile && tmp) {
                /* Restore release string and return V-R */
                *tmp = '-';
                tmp = strdup(rpmfile);
            } else {
                tmp = NULL;
            }
            free(newfile);
            if (tmp) {
                return tmp;
            }
        }
    }
    return NULL;
}

char
rpm_version_compare(const char *s1, const char *s2)
{
    char *ver[2], *rel[2];
    char ret;

    /* Parse s1 */
    ver[0] = rpm_get_version(s1);
    if (! ver[0]) {
        ver[0] = strdup(s1);
    }
    if ((rel[0] = strchr(ver[0], '-')) != NULL) {
        *rel[0] = 0;
        rel[0]++;
    }

    /* Parse s2 */
    ver[1] = rpm_get_version(s2);
    if (! ver[1]) {
        ver[1] = strdup(s2);
    }
    if ((rel[1] = strchr(ver[1], '-')) != NULL) {
        *rel[1] = 0;
        rel[1]++;
    }

    ret = rpmvercmp(ver[0], ver[1]);
    if (ret == 0 && rel[0] && rel[1]) {
        ret = rpmvercmp(rel[0], rel[1]);
    }
    free(ver[0]);
    free(ver[1]);
    return ret;
}

int
main(int argc, char *argv[])
{
    poptContext optCon = rpmcliInit(argc, argv, optionsTable);
    const char **av;
    char ret = 0;

    if (optCon == NULL) {
        exit(EXIT_FAILURE);
    }
    av = poptGetArgs(optCon);

    if (!av || !av[0] || !strcmp(av[0], "-")) {
        char buff[1024], *pbuff;

        /* Read from stdin */
        while (fgets(buff, sizeof(buff), stdin)) {
            if (*buff) {
                /* Kill trailing newline, if any. */
                pbuff = buff + strlen(buff) - 1;
                if (*pbuff == '\n') {
                    *pbuff = 0;
                }

                /* Find versions to compare. */
                pbuff = buff;
                while (!isspace(*pbuff)) pbuff++;
                while (isspace(*pbuff)) *pbuff++ = 0;

                /* Compare them. */
                ret = rpm_version_compare(buff, pbuff);
                printf("%s %c %s\n", buff, ((ret == 0) ? ('=') : ((ret < 0) ? ('<') : ('>'))), pbuff);
                fflush(stdout);
            }
        }
    } else if (!av[1]) {
        rpmlog(RPMLOG_ERR, "compare requires 2 parameters.\n");
        ret = 127;
    } else {
        /* Compare versions supplied on command line */
        ret = rpm_version_compare(av[0], av[1]);
        printf("%s %c %s\n", av[0], ((ret == 0) ? ('=') : ((ret < 0) ? ('<') : ('>'))), av[1]);
    }

    optCon = rpmcliFini(optCon);
    return ret;
}
