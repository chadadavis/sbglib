#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <float.h>
#include <math.h>

#include "pdb.h"

double const upper_limit = 1.8; //upper limit bond length for N- and O-containing bonds
double const c_o_2 = 1.413; //bond lengths
double const c_o_1 = 1.216;
double const co_carb = 1.250;
double const n_2_o_2 = 1.396;
double const no3_minus = 1.239;
double const c_sp3_n_3 = 1.482;
double const c_ar_sp3_n_4_2 = 1.474;


int get_minmax(char **set, int size, double *minmax){
	int it;
//	printf("%d\n", size);
	double minx = DBL_MAX;
	double maxx = DBL_MIN;
	double miny = DBL_MAX;
	double maxy = DBL_MIN;
	double minz = DBL_MAX;
	double maxz = DBL_MIN;
	for(it= 0; it < size; it++){
//		printf("%s", set[it]);
		char sub[8];
		strncpy(sub, set[it] + 30, 8);
		double x = atof(sub);
		strncpy(sub, set[it] + 38, 8);
		double y = atof(sub);
		strncpy(sub, set[it] + 46, 8);
		double z = atof(sub);
//		printf("%.3f %.3f %.3f\n", x, y, z);
		if(x < minx) minx = x;
		if(x > maxx) maxx = x;
		if(y < miny) miny = y;
		if(y > maxy) maxy = y;
		if(z < minz) minz = z;
		if(z > maxz) maxz = z;
	}
	minmax[0] = minx;
	minmax[1] = maxx;
	minmax[2] = miny;
	minmax[3] = maxy;
	minmax[4] = minz;
	minmax[5] = maxz;
//	printf("%.3f %.3f %.3f %.3f %.3f %.3f", minmax[0], minmax[1], minmax[2], minmax[3], minmax[4], minmax[5]);
}

int find_node(char *s, double minx, double miny, double minz, double step, int size_x, int size_y, int size_z){
	char sub[8];
	strncpy(sub, s + 30, 8);
	double x = atof(sub);
	strncpy(sub, s + 38, 8);
	double y = atof(sub);
	strncpy(sub, s + 46, 8);
	double z = atof(sub);
//	printf("%.3f %.3f %.3f\n", x, y, z);
	int offset_x = (int)((x - minx) / step);
	int offset_y = (int)((y - miny) / step);
	int offset_z = (int)((z - minz) / step);
//	printf("%d %d %d\n", offset_x, offset_y, offset_z);
	return (offset_z * size_y + offset_y) * size_x + offset_x;
}

double get_dist(char *line1, char *line2){
	double x1 = atof(line1 + 30);
	double y1 = atof(line1 + 38);
	double z1 = atof(line1 + 46);
	double x2 = atof(line2 + 30);
	double y2 = atof(line2 + 38);
	double z2 = atof(line2 + 46);
	return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + (z1 - z2) * (z1 - z2));
}

void assign_atom_type(int *atom_type, char **het, int size_h) {
	int it_h;
	for(it_h = 0; it_h < size_h; it_h++) {
		if(het[it_h][13] == 'C') atom_type[it_h] = NONE; //all carbons are neither donors noe acceptors
		else if((het[it_h][13] == 'N') || (het[it_h][13] == 'O')){ //nitrogens and oxygens are interesting
			int it_h2;
			int num_bonds = 0;
			char bonds[3];
			double dist[3];
			int contains_h = 0;
			int strange_atoms = 0;
			for(it_h2 = 0; it_h2 < size_h; it_h2++) {
				if(it_h2 != it_h) {
					double dist_c = get_dist(het[it_h], het[it_h2]); 
//					printf("%s%s%.3f\n", het[it_h], het[it_h2], dist_c);
					if((num_bonds < 4) && (dist_c < upper_limit)) {
						bonds[num_bonds] = het[it_h2][13];
						dist[num_bonds] = dist_c;
						if(bonds[num_bonds] == 'H') contains_h = 1;
						if((bonds[num_bonds] != 'C') && (bonds[num_bonds] != 'N') && (bonds[num_bonds] != 'O') && (bonds[num_bonds] != 'P') && (bonds[num_bonds] != 'F') && (bonds[num_bonds] != 'L') && (bonds[num_bonds] != 'I') && (bonds[num_bonds] != 'R')) strange_atoms = 1; 
						num_bonds++;
					}
					if(num_bonds >= 4) {
						printf("Too many bonds for %s", het[it_h]);
					}
				}
			}
//			printf("%s%d %d %d\n", het[it_h], num_bonds, contains_h, strange_atoms);
			if(((het[it_h][12] == ' ') && (het[it_h][13] == 'F')) || ((het[it_h][12] == 'C') && (het[it_h][13] == 'L')) || ((het[it_h][12] == ' ') && (het[it_h][13] == 'I')) || ((het[it_h][12] == 'B') && (het[it_h][13] == 'R'))) atom_type[it_h] = ACCEPTOR; // all halides are acceptors
			else if(((het[it_h][13] == 'N') && (num_bonds == 3) && (contains_h == 0)) || ((het[it_h][13] == 'O') && (num_bonds == 2) && (contains_h == 0))) atom_type[it_h] = NONE; //full binding, no hydrogens in the structure
			else if(num_bonds == 0) {
				printf("Isolated atom\n");
				atom_type[it_h] = NONE; //smth went wrong on an earlier stage: isolated atom
			}
			else {
				if(strange_atoms == 1) atom_type[it_h] = NONE; //some of the bound atoms are not C, N, O => do not mess around with it
				else {
					if(het[it_h][13] == 'O') {
						if(num_bonds == 1){
							if(bonds[0] == 'C'){
//								printf("%.3f %.3f %.3f\n", dist[0], c_o_2, co_carb);
								if((c_o_2 - dist[0]) < (dist[0] - co_carb)) atom_type[it_h] = DONOR; // C_O_2 bond
								else atom_type[it_h] = ACCEPTOR; // CO_CARB bond
							}else if(bonds[0] == 'O'){
								atom_type[it_h] = NONE;
							}else if(bonds[0] == 'N'){
								if((n_2_o_2 - dist[0]) < (dist[0] - no3_minus)) atom_type[it_h] = DONOR; // N_2_O_2 bond
								else atom_type[it_h] = ACCEPTOR; // NO3_MINUS or NO2 bond
							}else if(bonds[0] == 'P') {
								atom_type[it_h] = ACCEPTOR; // PO4-
							}else printf("This should never happen: %c %c\n", bonds[0], het[it_h][13]);
						}else atom_type[it_h] = NONE;
					}else if(het[it_h][13] == 'N') {
						if(num_bonds == 2) atom_type[it_h] = BOTH; // -C-N-C-, -C-N-O- - N can be donor or acceptor in different contexts (purines/pyrimidines) - Check!
						else {
							if(bonds[0] == 'C'){
								if((c_sp3_n_3 - dist[0]) < (dist[0] - c_ar_sp3_n_4_2)) atom_type[it_h] = DONOR; // C_SP3_N_4, C_SP3_N_3 bonds
								else atom_type[it_h] = BOTH; // DON'T KNOW!!! whatever: C_AR_SP3_N_4_2, C_AR_N_3, C_AR_N_PYR
							}else if(bonds[0] == 'O'){
								atom_type[it_h] = NONE; // N does not make H-bonds when there is an O around
							}else if(bonds[0] == 'N'){
								atom_type[it_h] = NONE; // N-N does not make H-bonds - Check!
							}else printf("This should never happen: %d %c %c\n", num_bonds, bonds[0], het[it_h][13]);
						}
					}
				}
			}
		}else atom_type[it_h] = NONE; //ignore the rest - Check! what about Cl, F, I???
//		printf("%s%d\n", het[it_h], atom_type[it_h]);
	}
}
