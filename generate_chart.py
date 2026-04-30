import matplotlib.pyplot as plt
import numpy as np

labels = ["FC", "EC-FF", "FC-FF", "EC", "EM", "EM-FF", "FM"]
local_times = [31, 7, 13, 12, 37, 9, 10]
gemini_times = [1153, 569, 991, 386, 1106, 981, 692]

x = np.arange(len(labels))
width = 0.35

fig, ax = plt.subplots(figsize=(10, 6))
rects1 = ax.bar(x - width/2, local_times, width, label='Local Parser (ms)', color='#2ca02c')
rects2 = ax.bar(x + width/2, gemini_times, width, label='Gemini API (ms)', color='#d62728')

ax.set_ylabel('Execution Time (ms) - Logarithmic Scale')
ax.set_title('Performance Benchmark: Local Parser vs. Gemini API')
ax.set_xticks(x)
ax.set_xticklabels(labels)
ax.set_yscale('log')
ax.legend()

for rect in rects1:
    h = rect.get_height()
    ax.annotate(f'{h}', xy=(rect.get_x() + rect.get_width() / 2, h),
                xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontsize=9)
for rect in rects2:
    h = rect.get_height()
    ax.annotate(f'{h}', xy=(rect.get_x() + rect.get_width() / 2, h),
                xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontsize=9)

plt.tight_layout()
plt.savefig('assets/images/performance_chart.png', dpi=300)
print("Chart generated successfully at assets/images/performance_chart.png")
