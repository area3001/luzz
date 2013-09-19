/*
  luzz-gen.c - the light generator - one led at a time

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
#include <time.h>
#include <mosquitto.h>

#include "../luzz.h"

int
main(int argc, char *argv[])
{
	int rc = 0;
	char *host = "localhost";
	int port = 1883;
	int keepalive = 60;
	char *id = NULL;
	bool clean_session = true;
	void *ctx = NULL;
	struct mosquitto *mosq = NULL;
	int timeout = 0;
	int max_packets = 1;
	int *mid = NULL;
	char *topic = NULL;
	int qos = 0;
	bool retain = 0;

    int panel = 0;
	int num_leds = 4;
	int rate = 2; /* fps */
	luzz_rgb_t *framep = NULL;

	int i = 0;
	bool red = true;

	struct timespec ts_remain;
	struct timespec ts_request = {
		.tv_sec = 0,
		.tv_nsec = 1e9 / rate
	};


	framep = calloc(num_leds, sizeof(luzz_grb_t));
	if (framep == NULL) {
		goto oom;
	}

	mosquitto_lib_init();

	if ((rc = asprintf(&id, LUZZ_GEN_ID_TPL, LUZZ_VERSION)) < 0) {
		goto oom;
	}
	mosq = mosquitto_new(id, clean_session, ctx);

	if (!mosq) {
		switch (errno) {
			case ENOMEM:
				rc = 1;
				goto oom;
			case EINVAL:
				fprintf(stderr, "mosq_new: Invalid id and/or clean_session.\n");
				rc = 1;
				goto finish;
		}
	}

	mosquitto_connect(mosq, host, port, keepalive);

	if ((rc = asprintf(&topic, LUZZ_TOPIC_TPL, panel)) < 0) {
		goto oom;
	}

	while (true) {
		(framep + i++)->r = red ? 0xFF : 0x00;

		if (i == num_leds - 1) {
			i = 0;
			red = !red;
		}

		mosquitto_publish(mosq, mid, topic, sizeof(luzz_rgb_t) * num_leds,
			(const void *)framep, qos, retain);

		while ((rc = mosquitto_loop(mosq, timeout, max_packets)) != MOSQ_ERR_SUCCESS) {
			switch (rc) {
				case MOSQ_ERR_INVAL:
					fprintf(stderr, "mosq_loop: Invalid input parameters.\n");
					goto finish;
				case MOSQ_ERR_NOMEM:
					goto oom;
				case MOSQ_ERR_PROTOCOL:
					fprintf(stderr, "mosq_loop: MQTT Protocol error.\n");
					goto finish;
				case MOSQ_ERR_ERRNO:
					perror("mosq_loop");
					goto finish;
				case MOSQ_ERR_NO_CONN:
					fprintf(stderr, "mosq_loop: No broker connection.\n");
					break;
				case MOSQ_ERR_CONN_LOST:
					fprintf(stderr, "mosq_loop: Connection to broker was lost.\n");
					break;
			}

			sleep(1);
			mosquitto_reconnect(mosq);
		}

		nanosleep(&ts_request, &ts_remain);
	}

oom:
	fprintf(stderr, "error: Out of memory.\n");
finish:
	mosquitto_destroy(mosq);
	mosquitto_lib_cleanup();

	return rc;
}
