#include "native_behavior.h"

namespace godot {

void register_linear();
void register_homing();
void register_accel();
void register_bounce_emit();
void register_accel_heading();
void register_split_after();

void register_behaviors_core() {
	register_linear();
	register_homing();
	register_accel();
	register_bounce_emit();
	register_accel_heading();
	register_split_after();
}

} // namespace godot
