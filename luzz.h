#define LUZZ_VERSION "0.1"
#define LUZZ_ID_TPL "luzz-v%s-i%d"
#define LUZZ_TOPIC_TPL "/luzz/%d"
#define LUZZ_STRIP_LPD8806 "lpd8806"
typedef struct {
	int index;
	char *dev;
	long speed; /* kbps */
	char *strip_type;
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
