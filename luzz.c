/*
  luzz.c - led there be light!

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
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>
#include <sched.h>
#include <sys/mman.h>
#include <mosquitto.h>

#include "luzz.h"

static inline void
luzz_rgb_to_lpd8806(luzz_ctx_t *ctxp, const struct mosquitto_message *msgp)
{
	luzz_rgb_t *i_framep = msgp->payload;
	luzz_grb_t *o_framep = ctxp->framep;

	int c, i;
	int cn = ctxp->num_leds / ctxp->col_length;
	int cl = ctxp->col_length;
	int off_even, i_off_odd, o_off_odd;

	luzz_rgb_t *i_framep_off = NULL;
	luzz_grb_t *o_framep_off = NULL;

	for (c = 0; c < cn - 1; c += 2) {
		for (i = 0; i < cl; i++) {
			off_even = c * cl + i;
			i_framep_off = i_framep + off_even;
			o_framep_off = o_framep + off_even;

			o_framep_off->r = (i_framep_off->r >> 1) | 0x80;
			o_framep_off->g = (i_framep_off->g >> 1) | 0x80;
			o_framep_off->b = (i_framep_off->b >> 1) | 0x80;

			i_off_odd = (c + 1) * cl + i;
			o_off_odd = (c + 2) * cl - i - 1;
			i_framep_off = i_framep + i_off_odd;
			o_framep_off = o_framep + o_off_odd;

			o_framep_off->r = (i_framep_off->r >> 1) | 0x80;
			o_framep_off->g = (i_framep_off->g >> 1) | 0x80;
			o_framep_off->b = (i_framep_off->b >> 1) | 0x80;
		}
	}

	/* odd number of columns */
	if (cn % 2) {
		for (i = 0; i < cl; i++) {
			off_even = (cn - 1) * cl + i;
			i_framep_off = i_framep + off_even;
			o_framep_off = o_framep + off_even;

			o_framep_off->r = (i_framep_off->r >> 1) | 0x80;
			o_framep_off->g = (i_framep_off->g >> 1) | 0x80;
			o_framep_off->b = (i_framep_off->b >> 1) | 0x80;
		}
	}
}

static void
luzz_on_message(struct mosquitto *mosq, void *objp, const struct mosquitto_message *msgp)
{
	luzz_ctx_t *ctxp = objp;

	if (msgp->payloadlen != sizeof(luzz_rgb_t) * ctxp->num_leds) {
		fprintf(stderr, "on_msg: Incorrect frame length (%d).\n", msgp->payloadlen);
		return;
	};
		
	switch (ctxp->strip_type) {
	case LUZZ_STRIP_LPD8806:
		luzz_rgb_to_lpd8806(ctxp, msgp);
		break;
	}

	write(ctxp->fd, ctxp->framep, (ctxp->num_leds + 1) * sizeof(luzz_grb_t)); 
}

static void
luzz_usage(const luzz_ctx_t *ctxp)
{
	fprintf(stderr,
		"Usage: luzz [-h host] [-p port] [-o device] [-s speed] [-t type]\n"
		"            [-i index] [-n num_leds] [-c col_length]\n"
		"            [-P priority] [-M]\n"
		"\n"
		"	-h : mqtt broker host address (%s)\n"
		"	-p : mqtt broker port (%d)\n"
		"	-o : output device to connect to (%s)\n"
		"	-s : spi bus speed in bps (%d)\n"
		"	-t : led strip type (lpd8806)\n"
		"	-i : led panel index (%d)\n"
		"	-n : number of leds on the strip (%d)\n"
		"	-c : number of leds per column (%d)\n"
		"	-P : realtime process scheduling priority (%d)\n"
		"	-M : lock all process memory (%d)\n"
		"\n",
		ctxp->mqttp->host,
		ctxp->mqttp->port,
		ctxp->dev,
		ctxp->speed_hz,
		ctxp->panel,
		ctxp->num_leds,
		ctxp->col_length,
		ctxp->rt_prio,
		ctxp->memlock
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
	};

	luzz_ctx_t ctx = {
		.mqttp = &mqtt,
		.panel = 0,
		.dev = "/dev/stdout",
		.speed_hz = 16000000,
		.strip_type = LUZZ_STRIP_LPD8806,
		.num_leds = 4,
		.col_length = 2,
		.framep = NULL,
		.rt_prio = -1,
		.memlock = -1,
	};

	while((opt = getopt(argc, argv, "h:p:o:s:t:i:n:c:P:M")) != -1) {
		switch (opt) {
		case 'h':
			mqtt.host = optarg;
			break;
		case 'p':
			mqtt.port = atoi(optarg);
			break;
		case 'o':
			ctx.dev = optarg;
			break;
		case 's':
			ctx.speed_hz = atoi(optarg);
			break;
		case 't':
			if (strcmp(optarg, "lpd8806") == 0) {
				ctx.strip_type = LUZZ_STRIP_LPD8806;
			};
			break;
		case 'i':
			ctx.panel = atoi(optarg);
			break;
		case 'n':
			ctx.num_leds = atoi(optarg);
			break;
		case 'c':
			ctx.col_length = atoi(optarg);
			break;
		case 'P':
			ctx.rt_prio = atoi(optarg);
			break;
		case 'M':
			ctx.memlock = 1;
			break;
		default:
			luzz_usage(&ctx);
			rc = -1;
			goto finish;
		}
	}

	struct sched_param sched = {
		.sched_priority = ctx.rt_prio
	};

	if (ctx.rt_prio > -1 && sched_setscheduler(0, SCHED_FIFO, &sched) == -1) {
		perror("rt_prio");
		goto finish;
	}

	if (ctx.memlock > -1 && mlockall(MCL_CURRENT | MCL_FUTURE) == -1) {
		perror("memlock");
		goto finish;
	}

	ctx.framep = calloc(ctx.num_leds + 1, sizeof(luzz_grb_t));
	if (ctx.framep == NULL) {
		goto oom;
	}

	if ((ctx.fd = rc = open(ctx.dev, O_WRONLY)) == -1) {
		perror(ctx.dev);
		goto finish;
	}

	if (strncmp("/dev/spidev", (const char *)ctx.dev, 11) == 0) {
		if ((rc = ioctl(ctx.fd, SPI_IOC_WR_MAX_SPEED_HZ, &ctx.speed_hz)) == -1) {
			perror("spi_speed");
			goto finish;
		}
	}

	mosquitto_lib_init();

	if ((rc = asprintf(&mqtt.id, LUZZ_ID_TPL, LUZZ_VERSION, ctx.panel)) < 0) {
		goto oom;
	}
	mosq = mosquitto_new(mqtt.id, mqtt.clean_session, &ctx);

	if (!mosq) {
		switch (errno) {
		case ENOMEM:
			rc = 2;
			goto oom;
		case EINVAL:
			fprintf(stderr, "mosq_new: Invalid id and/or clean_session.\n");
			rc = 2;
			goto finish;
		}
	}

	mosquitto_message_callback_set(mosq, luzz_on_message);
	mosquitto_connect(mosq, mqtt.host, mqtt.port, mqtt.keepalive);

	if ((rc = asprintf(&mqtt.topic, LUZZ_TOPIC_TPL, ctx.panel)) < 0) {
		goto oom;
	}
	mosquitto_subscribe(mosq, mqtt.mid, mqtt.topic, mqtt.qos);

	while (true) {
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
			mosquitto_subscribe(mosq, mqtt.mid, mqtt.topic, mqtt.qos);
		}
	}

oom:
	fprintf(stderr, "error: Out of memory.\n");
finish:
	mosquitto_destroy(mosq);
	mosquitto_lib_cleanup();

	return rc;
}
