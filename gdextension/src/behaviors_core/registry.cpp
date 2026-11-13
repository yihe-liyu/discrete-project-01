#include "native_behavior.h"

namespace godot {

void register_linear();
void register_homing();
void register_accel();

void register_behaviors_core() {
	register_linear();
	register_homing();
	register_accel();
}

} // namespace godot
