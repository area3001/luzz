#define LUZZ_VERSION "0.1"

#define LUZZ_ID_TPL "luzz-v%s-i%d"
#define LUZZ_GEN_ID_TPL "luzz-gen-v%s"
#define LUZZ_TOPIC_TPL "/luzz/%d"

#define LUZZ_STRIP_LPD8806 0

typedef struct {
	int panel;
	char *dev;
	long speed_hz;
	int fd;
	int strip_type;
	int num_leds;
	int col_length;
	void *framep;
} luzz_ctx_t;

typedef struct {
	char r;
	char g;
	char b;
} luzz_rgb_t;

typedef struct {
	char g;
	char r;
	char b;
} luzz_grb_t;
