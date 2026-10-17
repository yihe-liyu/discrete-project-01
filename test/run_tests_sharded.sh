#!/usr/bin/env bash
# 并行 GUT —— 把 test/test_*.gd 分成 N 片、每片一个 Godot 进程。
#
# 为什么：全量 GUT ~54s，其中单文件 test_sfx_mix / test_stage_background 很重；
# 分片后墙钟 ~15s（14 核，8 片），覆盖仍是**全量**（每片都走 run_tests.sh 的隔离与门禁）。
#
# 用法:
#   ./test/run_tests_sharded.sh              # 默认 min(nproc, 8) 片；<3 自动退回串行
#   GUT_SHARDS=6 ./test/run_tests_sharded.sh # 指定片数
#   ./test/run_tests_sharded.sh --serial     # 串行全量（排查顺序/共享状态问题）
#
# 覆盖保证：每个 test/test_*.gd 恰好进一片；慢文件各占一片，避免一片 24s 拖住墙钟。
set -u
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--serial" ]]; then
	exec ./test/run_tests.sh
fi

if [[ -n "${GUT_SHARDS:-}" ]]; then
	shards="$GUT_SHARDS"
else
	cpus="$(nproc 2>/dev/null || echo 4)"
	shards="$cpus"
	(( shards > 8 )) && shards=8
	(( shards < 2 )) && shards=2
fi
if ! [[ "$shards" =~ ^[0-9]+$ ]] || (( shards < 3 )); then
	echo "GUT_SHARDS=$shards < 3 → 退回串行全量（并行至少 3 片）"
	exec ./test/run_tests.sh
fi

mapfile -t all < <(ls test/test_*.gd 2>/dev/null | sort)
if (( ${#all[@]} == 0 )); then
	echo "❌ 没有 test/test_*.gd"
	exit 2
fi

# 已知慢文件：各占一片；其余按 round-robin 分到剩余片。
slow_candidates=(test/test_sfx_mix.gd test/test_stage_background.gd)
slow=()
for s in "${slow_candidates[@]}"; do
	[[ -f "$s" ]] && slow+=("$s")
done
slow_count=${#slow[@]}
rest=()
for f in "${all[@]}"; do
	skip=0
	for s in "${slow[@]}"; do
		[[ "$f" == "$s" ]] && skip=1
	done
	(( skip == 0 )) && rest+=("$f")
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pids=()
lists=()
start=$(date +%s%N)

for ((i = 0; i < shards; i++)); do
	list=()
	if (( i < slow_count )); then
		list+=("res://${slow[$i]}")
		# 片数刚好只比慢文件多 1：剩余全塞这一片，避免空片
		if (( shards == slow_count + 1 )); then
			for ((j = i; j < ${#rest[@]}; j += shards)); do
				list+=("res://${rest[$j]}")
			done
		fi
	else
		k=$((i - slow_count))
		step=$((shards - slow_count))
		for ((j = k; j < ${#rest[@]}; j += step)); do
			list+=("res://${rest[$j]}")
		done
	fi
	if (( ${#list[@]} == 0 )); then
		lists[$i]=""
		pids[$i]=""
		continue
	fi
	joined="$(IFS=,; echo "${list[*]}")"
	lists[$i]="$joined"
	./test/run_tests.sh -gtest="$joined" > "$tmp/$i.log" 2>&1 &
	pids[$i]=$!
done

fail=0
for i in "${!pids[@]}"; do
	[[ -z "${pids[$i]}" ]] && continue
	if ! wait "${pids[$i]}"; then
		fail=1
	fi
done
end=$(date +%s%N)
wall_ms=$(( (end - start) / 1000000 ))

total_tests=0
total_asserts=0
for i in "${!lists[@]}"; do
	[[ -z "${lists[$i]}" ]] && continue
	tests="$(grep -E '^Tests ' "$tmp/$i.log" | awk '{print $2}' | tail -1)"
	asserts="$(grep -E '^Asserts ' "$tmp/$i.log" | awk '{print $2}' | tail -1)"
	tests="${tests:-0}"
	asserts="${asserts:-0}"
	total_tests=$((total_tests + tests))
	total_asserts=$((total_asserts + asserts))
	time_line="$(grep -E '^Time ' "$tmp/$i.log" | awk '{print $2}' | tail -1)"
	printf "  片 %d: %s 用例 / %s 断言 / %s\n" "$i" "$tests" "$asserts" "${time_line:-?}"
	if grep -q "Failed to load script" "$tmp/$i.log"; then
		echo "  ❌ 片 $i 有测试脚本加载失败"
		fail=1
	fi
	if grep -qE "^Risky/Pending" "$tmp/$i.log"; then
		echo "  ❌ 片 $i 有 pending/risky"
		fail=1
	fi
done

printf "\n  合计：%d 用例 / %d 断言 / 墙钟 %.1fs（%d 片）\n" \
	"$total_tests" "$total_asserts" "$(awk -v ms="$wall_ms" 'BEGIN{printf "%.3f", ms/1000}')" "$shards"

if (( fail != 0 )); then
	echo ""
	echo "❌ 有分片失败；下面是失败分片的日志："
	for i in "${!lists[@]}"; do
		[[ -z "${lists[$i]}" ]] && continue
		if ! grep -q "All tests passed" "$tmp/$i.log"; then
			echo ""
			echo "══════ 片 $i ══════"
			tail -120 "$tmp/$i.log"
		fi
	done
	exit 1
fi

echo "  ✅ 全部分片通过（覆盖 = 全量 test/*.gd）"
exit 0
