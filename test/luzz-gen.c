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

#define _GNU_SOURCE

#include <stdlib.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <mosquitto.h>

#include "../luzz.h"

void
luzz_gen_usage(const luzz_ctx_t *ctxp)
{
	fprintf(stderr,
		"Usage: luzz_gen [-h host] [-p port] [-i index] [-n num_leds] [-r fps]\n"
		"\n"
		"	-h : mqtt broker host address (%s)\n"
		"	-p : mqtt broker port (%d)\n"
		"	-i : led panel index (%d)\n"
		"	-n : number of leds on the strip (%d)\n"
		"	-r : frame rate in fps (%d)\n"
		"\n",
		ctxp->mqttp->host,
		ctxp->mqttp->port,
		ctxp->panel,
		ctxp->num_leds,
		ctxp->fps
	);
}

int
main(int argc, char *argv[])
{
	int opt;
	int rc = 0;
	struct mosquitto *mosq = NULL;

	luzz_mqtt_t mqtt = {
		.host = "localhost",
		.port = 1883,
		.keepalive = 60,
		.id = NULL,
		.clean_session = true,
		.timeout = -1,
		.max_packets = 1,
		.mid = NULL,
		.topic = NULL,
		.qos = 0,
		.retain = 0,
	};

	luzz_ctx_t ctx = {
		.mqttp = &mqtt,
		.panel = 0,
		.num_leds = 4,
		.fps = 2,
		.framep = NULL,
	};

	while ((opt = getopt(argc, argv, "h:p:i:n:r:")) != -1) {
		switch (opt) {
		case 'h':
			mqtt.host = optarg;
			break;
		case 'p':
			mqtt.port = atoi(optarg);
			break;
		case 'i':
			ctx.panel = atoi(optarg);
			break;
		case 'n':
			ctx.num_leds = atoi(optarg);
			break;
		case 'r':
			ctx.fps = atoi(optarg);
			break;
		default:
			luzz_gen_usage(&ctx);
			goto finish;
		}
	}

	int i = 0;
	bool red = true;

	struct timespec ts_remain;
	struct timespec ts_request = {
		.tv_sec = 0,
		.tv_nsec = 1e9 / ctx.fps
	};

	ctx.framep = calloc(ctx.num_leds, sizeof(luzz_grb_t));
	if (ctx.framep == NULL) {
		goto oom;
	}

	mosquitto_lib_init();

	if ((rc = asprintf(&mqtt.id, LUZZ_GEN_ID_TPL, LUZZ_VERSION)) < 0) {
		goto oom;
	}
	mosq = mosquitto_new(mqtt.id, mqtt.clean_session, &ctx);

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

	mosquitto_connect(mosq, mqtt.host, mqtt.port, mqtt.keepalive);

	if ((rc = asprintf(&mqtt.topic, LUZZ_TOPIC_TPL, ctx.panel)) < 0) {
		goto oom;
	}

	while (true) {
		((luzz_rgb_t *)ctx.framep + i++)->r = red ? 0xFF : 0x00;

		if (i == ctx.num_leds - 1) {
			i = 0;
			red = !red;
		}

		mosquitto_publish(mosq, mqtt.mid, mqtt.topic, sizeof(luzz_rgb_t) * ctx.num_leds,
			(const void *)ctx.framep, mqtt.qos, mqtt.retain);

		while ((rc = mosquitto_loop(mosq,
				mqtt.timeout, mqtt.max_packets)) != MOSQ_ERR_SUCCESS) {
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
