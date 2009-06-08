#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <time.h>

#include "pdb.h"


int calc_intersection(char **prot, int size_p, int *nodes, double step, int size_x, int size_y, int size_z, double *minmax){
	int intersection = 0;
	int it_p;
	for(it_p = 0; it_p < size_p; it_p++) {
		char sub[8];
		strncpy(sub, prot[it_p] + 30, 8);
		double x = atof(sub);
		strncpy(sub, prot[it_p] + 38, 8);
		double y = atof(sub);
		strncpy(sub, prot[it_p] + 46, 8);
		double z = atof(sub);
		if((x > minmax[0]) && (x < minmax[1]) && (y > minmax[2]) && (y < minmax[3]) && (z > minmax[4]) && (z < minmax[5])) {
//			printf("%d %d %d %s", size_x, size_y, size_z, prot[it_p]);
//			printf("%d\n", find_node(prot[it_p], minmax[0], minmax[2], minmax[4], step, size_x, size_y, size_z));
			if(nodes[find_node(prot[it_p], minmax[0], minmax[2], minmax[4], step, size_x, size_y, size_z)] == 1) {
				intersection++;
			}
		}
	}
	return intersection;
}

void calc_contacts(char **prot, int size_p, char **het, int size_h, double cutoff, double *minmax, int *cont_p, int *h_bond_p, int *vdw_p){
	int contacts = 0;
	int h_bonds = 0;
	int vdw = 0;
	int it_p, it_h;
	int *atom_type;
	atom_type = (int *)malloc(size_h * sizeof(int));
	int *het_h_bonds, *prot_h_bonds;
	het_h_bonds = (int *)malloc(size_h * sizeof(int));
	prot_h_bonds = (int *)malloc(size_p * sizeof(int));
	assign_atom_type(atom_type, het, size_h);
	for(it_p = 0; it_p < size_p; it_p++) prot_h_bonds[it_p] = 0;
	for(it_h = 0; it_h < size_h; it_h++) het_h_bonds[it_h] = 0;
	for(it_p = 0; it_p < size_p; it_p++)
		for(it_h = 0; it_h < size_h; it_h++){
			char sub[8];
			double xh = atof(het[it_h] + 30);
			double yh = atof(het[it_h] + 38);
			double zh = atof(het[it_h] + 46);
			char ah_1 = het[it_h][76];
			char ah_2 = het[it_h][77];
			double xp = atof(prot[it_p] + 30);
			double yp = atof(prot[it_p] + 38);
			double zp = atof(prot[it_p] + 46);
			char ap_1 = prot[it_p][76];
			char ap_2 = prot[it_p][77];
			if((ap_1 == ' ') && (xp > minmax[0] - cutoff) && (xp < minmax[1] + cutoff) && (yp > minmax[2] - cutoff) && (yp < minmax[3] + cutoff) && (zp > minmax[4] - cutoff) && (zp < minmax[5] + cutoff)){
				double d = (xp -xh) * (xp - xh) + (yp - yh) * (yp - yh) + (zp - zh) * (zp - zh);
				if(d < cutoff * cutoff) { 
					contacts++;
//					printf("%s%s%c %c %c %c\n", het[it_h], prot[it_p], ah_1, ah_2, ap_1, ap_2);
					if((ah_1 == ' ') && (ap_1 == ' ') && (ah_2 == 'C') && (ap_2 == 'C')) {
//						printf("VdW\n");
						vdw++; //VdW interaction possible between 2 C's lying closer than the cutoff
					}
					else {
//						printf("%s%s%c %c %c %c\n", het[it_h], prot[it_p], ah_1, ah_2, ap_1, ap_2);
//						printf("H-bond: het atom type: %d\n", atom_type[it_h]);
						if((het_h_bonds[it_h] == 0) && (prot_h_bonds[it_p] == 0)) { // an new H-bond is added only if the atom of the ligand and the atom of the protein are not involved in other H-bonds (may cause some underestimation, but not terrible)
							h_bonds += is_h_bond(het[it_h], prot[it_p], atom_type[it_h]); //decide if the interaction is an H-bond
							het_h_bonds[it_h] = 1;
							prot_h_bonds[it_p] = 1;
						}
					}
				}
			}

		}
	free(atom_type);
	free(het_h_bonds);
	free(prot_h_bonds);
	*cont_p = contacts;
	*h_bond_p = h_bonds;
	*vdw_p = vdw;
}

int is_h_bond(char *het_line, char *prot_line, int het_atom_type) {
//	printf("H-bonds entered\n");
	char prot_atom_name[5];
	strncpy(prot_atom_name, prot_line + 12, 4);
	prot_atom_name[4] = 0;
	char prot_aa[4];
	strncpy(prot_aa, prot_line + 17, 3);
	prot_aa[3] = 0;
	int prot_atom_type;
	if((prot_atom_name[1] == 'C') || (prot_atom_name[1] == 'S')) prot_atom_type = NONE; // all C and S are neither donors not acceptors
	else if(prot_atom_name[1] == 'N') {
		if((strcmp(prot_atom_name, " N  ") == 0) || (((strcmp(prot_atom_name, " NH1") == 0) || (strcmp(prot_atom_name, " NH2") == 0)) && (strcmp(prot_aa, "ARG") == 0)) || ((strcmp(prot_atom_name, " ND2") == 0) && (strcmp(prot_aa, "ASN") == 0)) || ((strcmp(prot_atom_name, " NE2") == 0) && (strcmp(prot_aa, "GLN") == 0))) prot_atom_type = DONOR; // N2H
		else if(((strcmp(prot_atom_name, " NE1") == 0) && (strcmp(prot_aa, "TRP") == 0)) || ((strcmp(prot_atom_name, " NE2") == 0) && (strcmp(prot_aa, "HIS") == 0))) prot_atom_type = NONE; //NarH
		else if((strcmp(prot_atom_name, " ND1") == 0) && (strcmp(prot_aa, "HIS") == 0)) prot_atom_type = DONOR; // NarH+
		else if((strcmp(prot_atom_name, " NZ ") == 0) && (strcmp(prot_aa, "LYS") == 0)) prot_atom_type = DONOR; // N3H+
		else if((strcmp(prot_atom_name, " NE ") == 0) && (strcmp(prot_aa, "ARG") == 0)) prot_atom_type = DONOR; // N2H+
		else if(((strcmp(prot_atom_name, " NE1") == 0) && (strcmp(prot_aa, "TRP") == 0)) || ((strcmp(prot_atom_name, " NE2") == 0) && (strcmp(prot_aa, "HIS") == 0))) prot_atom_type = DONOR; // NarH
		else prot_atom_type = NONE; // smth weird, do not mess aroung with it
	}else if(prot_atom_name[1] == 'O') {
		if((strcmp(prot_atom_name, " O  ") == 0) || ((strcmp(prot_atom_name, " OD1") == 0) && (strcmp(prot_aa, "ASN") == 0)) || ((strcmp(prot_atom_name, " OE1") == 0) && (strcmp(prot_aa, "GLN") == 0))) prot_atom_type = ACCEPTOR; // O=
		else if(((strcmp(prot_atom_name, " OG ") == 0) && (strcmp(prot_aa, "SER") == 0)) || ((strcmp(prot_atom_name, " OG1") == 0) && (strcmp(prot_aa, "THR") == 0)) || ((strcmp(prot_atom_name, " OH ") == 0) && (strcmp(prot_aa, "TYR") == 0))) prot_atom_type = DONOR; // OH
		else if((strcmp(prot_atom_name, " OXT") == 0) || (((strcmp(prot_atom_name, " OD1") == 0) || (strcmp(prot_atom_name, " OD2") == 0)) && (strcmp(prot_aa, "ASP") == 0)) || (((strcmp(prot_atom_name, " OE1") == 0) || (strcmp(prot_atom_name, " OE2") == 0)) && (strcmp(prot_aa, "GLU") == 0))) prot_atom_type = ACCEPTOR; // O2-
		else prot_atom_type = NONE; //smth weird, do not mess around with it
	}else prot_atom_type = NONE; //some weird atom, do not mess around with it
	if(((het_atom_type == DONOR) && (prot_atom_type == ACCEPTOR)) || ((het_atom_type == ACCEPTOR) && (prot_atom_type == DONOR))) return 1;
	if((het_atom_type == BOTH) && ((prot_atom_type == DONOR) || (prot_atom_type == ACCEPTOR) || (prot_atom_type == BOTH))) return 1;
	if((prot_atom_type == BOTH) && ((het_atom_type == DONOR) || (het_atom_type == ACCEPTOR) || (het_atom_type == BOTH))) return 1;
	return 0;
}


void append_result(char const* outfile, char const* comment, 
                   int size_h, double intersection, 
                   int contacts, int h_bonds, int vdw) {

		FILE *out;
		out = fopen(outfile, "a");
//		printf("File %s opened\n", argv[4]);
		if(out == NULL){
			perror("File not opened");
			exit(1);
		}
		char sout[strlen(comment) + 100];
		sprintf(sout, "%s\t%d\t%.3f\t%.3f\t%d\t%.3f\t%d\t%.3f\t%d\t%.3f\n", comment, size_h, intersection, intersection / size_h, contacts, (double)contacts / size_h, h_bonds, (double)h_bonds / size_h, vdw, (double)vdw / size_h);
		fputs(sout, out);
		fclose(out);
}


int main(int argc, char **argv) {
	time_t t_start = time(NULL);
	if(argc < 5) {
		perror("Not enough arguments");
		exit(-1);
	}
	double step = atof(argv[2]);
	double cutoff = atof(argv[3]);
	//read data
	char comment[1000];
	FILE *com_in;
	com_in = fopen(argv[5], "r");
	if(com_in == NULL) {
		printf("%s: ", argv[5]);
		perror("File not opened");
		exit(1);
	}
	fgets(comment, 1000, com_in);
	fclose(com_in);
	FILE *f;
	f = fopen(argv[1], "r");
	if(f == NULL) {
		perror("File not opened");
		exit(1);
	}
	int size_p = 0, size_h = 0;
	char alt, alt_prev = ' ';
	int flag_alt = 1;
	while(!feof(f)){
		char curr[100];
		fgets(curr, 100, f);
		if(!feof(f)){
		alt = curr[16];
		if((curr[21] == 'B') && (alt_prev != alt) && (alt_prev != ' ')) flag_alt = 0;
		if((curr[21] == 'B') && flag_alt) size_h++;
		else if(curr[0] == 'A') size_p++;
//		printf("%c %c\n", alt_prev, alt);
		alt_prev = alt;
		}
	}
	fclose(f);
//	printf("%d %d\n", size_h, size_p);
	char **het, **prot;
	het = (char **)malloc(size_h * sizeof(char *));
	prot = (char **)malloc(size_p * sizeof(char *));
	int it_h = 0, it_p = 0;
	for(it_h = 0; it_h < size_h; it_h++) het[it_h] = (char *)malloc(100 * sizeof(char));
	for(it_p = 0; it_p < size_p; it_p++) prot[it_p] = (char *)malloc(100 * sizeof(char));
	f = fopen(argv[1], "r");
	it_h = 0; it_p = 0;
	alt_prev = ' ';
	flag_alt = 1;
	while(!feof(f)){
		char curr[83];
		fgets(curr, 83, f);
		if(!feof(f)){
		alt = curr[16];
		if((curr[21] == 'B') && (alt_prev != alt) && (alt_prev != ' ')) flag_alt = 0;
		if(curr[0] != 'R'){
			if((curr[21] == 'B') && flag_alt) {
//				printf("%s", curr);
				strncpy(het[it_h], curr, 82);
				het[it_h][82] = 0;
				it_h++;
			}else if(curr[0] == 'A') {
				strncpy(prot[it_p], curr, 82);
				prot[it_p][82] = 0;
				it_p++;
			}
		}
//		printf("%c %c\n", alt_prev, alt);
		alt_prev = alt;
		}
		
	}
	fclose(f);
//	printf("protein read\n");
	//test input
	int it;
//	for(it = 0; it < size_h; it++) printf("%s", het[it]);
	//do real stuff
	double *minmax;
	minmax = (double *)malloc(6 * sizeof(double));
	get_minmax(het, size_h, minmax);
//	printf("Minmax read\n");
	int *nodes;
	int size_x = (int)((minmax[1] - minmax[0]) / step) + 2;
	int size_y = (int)((minmax[3] - minmax[2]) / step) + 2;
	int size_z = (int)((minmax[5] - minmax[4]) / step) + 2;
	int node_num = size_x * size_y * size_z;
	nodes = (int *)malloc(node_num * sizeof(int));
	for(it = 0; it < node_num; it++) nodes[it] = 0;
	for(it_h = 0; it_h < size_h; it_h++) {
		nodes[find_node(het[it_h], minmax[0], minmax[2], minmax[4], step, size_x, size_y, size_z)] = 1;
	}
//	printf("Nodes read\n");
	double intersection = 0;
	intersection = (double)calc_intersection(prot, size_p, nodes, step, size_x, size_y, size_z, minmax) * step * step * step;
	int contacts = -1;
	int h_bonds = -1;
	int vdw = -1;
	if(intersection / size_h < 2){
//		printf("Starting contacts\n");
		calc_contacts(prot, size_p, het, size_h, cutoff, minmax, &contacts, &h_bonds, &vdw);
	}
	//free memory
	for(it_h = 0; it_h < size_h; it_h++) free(het[it_h]);
	for(it_p = 0; it_p < size_p; it_p++) free(prot[it_p]);
	free(het);
	free(prot);
	free(minmax);
	free(nodes);
//	printf("Intersection = %d\n", intersection);
	printf("Time elapsed: %.3f\n", difftime(time(NULL), t_start));

	if((intersection > 0) || (contacts > 0)){
      append_result(argv[4], size_h, intersection, contacts, h_bonds, vdw);
	}
}
