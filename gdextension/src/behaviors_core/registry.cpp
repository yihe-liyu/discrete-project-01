#include "native_behavior.h"

namespace godot {

void register_linear();
void register_homing();
void register_accel();
void register_bounce_emit();
void register_accel_heading();
void register_split_after();
void register_seed_burst();
void register_spin_accel();
void register_top_emit();
void register_spin_then_slow();
void register_rain_stage();
void register_sonar();
void register_anchor_drift();

void register_behaviors_core() {
	register_linear();
	register_homing();
	register_accel();
	register_bounce_emit();
	register_accel_heading();
	register_split_after();
	register_seed_burst();
	register_spin_accel();
	register_top_emit();
	register_spin_then_slow();
	register_rain_stage();
	register_sonar();
	register_anchor_drift();
}

} // namespace godot
