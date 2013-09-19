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

static void
luzz_on_message(struct mosquitto *mosq, void *obj, const struct mosquitto_message *msg)
{
	luzz_ctx_t *ctxp = obj;
}

int
main(int argc, char *argv[])
{
	int rc = 0;
	char *host = "localhost";
	int port = 1883;
	int keepalive = 60;
	char *id = NULL;
	bool clean_session = true;
	struct mosquitto *mosq = NULL;
	char err[128];
	int timeout = -1;
	int max_packets = 1;
	int *mid = NULL;
	char *topic = NULL;
	int qos = 0;

	luzz_ctx_t ctx = {
		.index = 0,
		.dev = "/dev/stdout",
		.speed = 16000,
		.strip_type = LUZZ_STRIP_LPD8806,
		.num_leds = 64,
		.col_length = 8,
		.framep = NULL,
	};

	ctx.framep = calloc(ctx.num_leds + 1, sizeof(luzz_grb_t));
	if (ctx.framep == NULL) {
		goto oom;
	}

	mosquitto_lib_init();

	if ((rc = asprintf(&id, LUZZ_ID_TPL, LUZZ_VERSION, ctx.index)) < 0) {
		goto oom;
	}
	mosq = mosquitto_new(id, clean_session, &ctx);

	if (!mosq) {
		switch (errno) {
			case ENOMEM:
				rc = 1;
				goto oom;
			case EINVAL:
				fprintf(stderr, "Error: Invalid id and/or clean_session.\n");
				rc = 1;
				goto finish;
		}
	}

	mosquitto_message_callback_set(mosq, luzz_on_message);
	mosquitto_connect(mosq, host, port, keepalive);

	if ((rc = asprintf(&topic, LUZZ_TOPIC_TPL, ctx.index)) < 0) {
		goto oom;
	}
	mosquitto_subscribe(mosq, mid, topic, qos);

	while (true) {
		while ((rc = mosquitto_loop(mosq, timeout, max_packets)) != MOSQ_ERR_SUCCESS) {
			switch (rc) {
				case MOSQ_ERR_INVAL:
					fprintf(stderr, "Error: Invalid input parameters.\n");
					goto finish;
				case MOSQ_ERR_NOMEM:
					goto oom;
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
			mosquitto_subscribe(mosq, mid, topic, qos);
		}
	}

oom:
	fprintf(stderr, "Error: Out of memory.\n");
finish:
	mosquitto_destroy(mosq);
	mosquitto_lib_cleanup();

	return rc;
}
