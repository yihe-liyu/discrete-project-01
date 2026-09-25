#include "hello.h"

using namespace godot;

void Hello::_bind_methods() {
	ClassDB::bind_method(D_METHOD("greet"), &Hello::greet);
}

Hello::Hello() {}
Hello::~Hello() {}

String Hello::greet() const {
	return "Hello from GDExtension (api 4.7)";
}
