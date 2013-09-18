/*
  luzz.c - Let there be light!

  Copyright (C) 2013 Bart Van Der Meerssche <bart@flukso.net>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#define _GNU_SOURCE 1

#include <stdlib.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <mosquitto.h>

#include "luzz.h"

int
main(int argc, char *argv[])
{
	int i;
	int rc = 0;
	int index = 0;
	char *host = "localhost";
	int port = 1883;
	int keepalive = 60;
	char *id = NULL;
	bool clean_session = true;
	struct mosquitto *mosq = NULL;
	char err[128];
	int timeout = -1;
	int max_packets = 1;

	mosquitto_lib_init();

	if ((rc = asprintf(&id, LUZZ_ID_TPL, LUZZ_VERSION, index)) < 0) {
		fprintf(stderr, "Error: Out of memory.\n");
		goto finish;
	}

	mosq = mosquitto_new(id, clean_session, NULL); /* TODO pass a ctx */

	if (!mosq) {
		switch (errno) {
			case ENOMEM:
				fprintf(stderr, "Error: Out of memory.\n");
				rc = 1;
				goto finish;
			case EINVAL:
				fprintf(stderr, "Error: Invalid id and/or clean_session.\n");
				rc = 1;
				goto finish;
		}
	}

	mosquitto_connect(mosq, host, port, keepalive);

	while (true) {
		while ((rc = mosquitto_loop(mosq, timeout, max_packets)) != MOSQ_ERR_SUCCESS) {
			switch (rc) {
				case MOSQ_ERR_INVAL:
					fprintf(stderr, "Error: Invalid input parameters.\n");
					goto finish;
				case MOSQ_ERR_NOMEM:
					fprintf(stderr, "Error: Out of memory.\n");
					goto finish;
				case MOSQ_ERR_PROTOCOL:
					fprintf(stderr, "Errpr: MQTT Protocol error.\n");
					goto finish;
				case MOSQ_ERR_ERRNO:
					strerror_r(errno, err, sizeof(err));
					fprintf(stderr, "Error: %s\n", err);
					goto finish;
				case MOSQ_ERR_NO_CONN:
					fprintf(stderr, "Error: No broker connection.\n");
					break;
				case MOSQ_ERR_CONN_LOST:
					fprintf(stderr, "Error: Connection to broker was lost.\n");
					break;
			}

			sleep(1);
			mosquitto_reconnect(mosq);
		}
	}

finish:
	mosquitto_destroy(mosq);
	mosquitto_lib_cleanup();

	return rc;
}
