cairohack.so: cairohack.cpp
	g++ -shared -o cairohack.so -fPIC  -llua cairohack.cpp -Wall -Wextra
