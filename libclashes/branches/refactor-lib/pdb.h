
#define DONOR 1
#define ACCEPTOR 2
#define BOTH 3
#define NONE 0

extern double const upper_limit; //upper limit bond length for N- and O-containing bonds
extern double const c_o_2; //bond lengths
extern double const c_o_1;
extern double const co_carb;
extern double const n_2_o_2;
extern double const no3_minus;
extern double const c_sp3_n_3;
extern double const c_ar_sp3_n_4_2;


int get_minmax(char **set, int size, double *minmax);


int find_node(char *s, double minx, double miny, double minz, double step, int size_x, int size_y, int size_z);


void assign_atom_type(int *atom_type, char **het, int size_h);


double get_dist(char *line1, char *line2);


int get_minmax(char **set, int size, double *minmax);


int find_node(char *s, double minx, double miny, double minz, double step, int size_x, int size_y, int size_z);


double get_dist(char *line1, char *line2);


void assign_atom_type(int *atom_type, char **het, int size_h);



