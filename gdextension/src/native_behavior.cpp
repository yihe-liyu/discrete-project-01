#include "native_behavior.h"

namespace godot {

std::vector<NativeBehaviorDef> &NativeBehaviorRegistry::_defs() {
	static std::vector<NativeBehaviorDef> defs;
	return defs;
}

int NativeBehaviorRegistry::register_def(const NativeBehaviorDef &p_def) {
	auto &defs = _defs();
	for (int i = 0; i < (int)defs.size(); ++i) {
		if (String(defs[i].name) == String(p_def.name)) {
			return i;
		}
	}
	defs.push_back(p_def);
	return (int)defs.size() - 1;
}

int NativeBehaviorRegistry::find_id(const String &p_name) {
	auto &defs = _defs();
	for (int i = 0; i < (int)defs.size(); ++i) {
		if (String(defs[i].name) == p_name) {
			return i;
		}
	}
	return -1;
}

const NativeBehaviorDef *NativeBehaviorRegistry::get(int p_id) {
	auto &defs = _defs();
	if (p_id < 0 || p_id >= (int)defs.size()) {
		return nullptr;
	}
	return &defs[p_id];
}

String NativeBehaviorRegistry::get_name(int p_id) {
	const NativeBehaviorDef *def = get(p_id);
	return def ? String(def->name) : String();
}

int NativeBehaviorRegistry::size() {
	return (int)_defs().size();
}

} // namespace godot
