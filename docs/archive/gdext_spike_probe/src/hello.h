#ifndef HELLO_H
#define HELLO_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class Hello : public RefCounted {
	GDCLASS(Hello, RefCounted)

protected:
	static void _bind_methods();

public:
	String greet() const;

	Hello();
	~Hello();
};

} // namespace godot

#endif
