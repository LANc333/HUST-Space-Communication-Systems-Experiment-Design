# 延迟锁定环（DLL）仿真

本实验根据《延迟锁定环》课件，模拟 GPS C/A PRN 20 的码相关输出、DLL 码相位鉴别器，以及噪声对鉴别器的影响。

## 运行

在 MATLAB 当前文件夹切换到本目录，然后运行：

```matlab
results = run_dll_experiment;
```

运行验证：

```matlab
verify_dll_experiment
```

主函数使用 MATLAB 基础功能，无需额外工具箱。默认把图、结果摘要和 MAT 数据写入本目录，也可传入其他输出路径。

## 仿真条件

| 参数 | 数值 |
| --- | --- |
| GPS C/A 码 | PRN 20，1023 码片 |
| 码速率 | 1.023 MHz |
| 采样率 | 100 MHz，约 97.75 点/码片 |
| 相干积分时间 | 1 ms |
| 接收传播延迟 | 30 ms |
| 接收多普勒 | 1000 Hz |
| 本地延迟误差扫描 | -100 至 +100 Tc，步进 0.1 Tc |
| 超前-滞后间隔 | 1 Tc |
| 噪声条件 | 0、-10、-20、-50 dB |

每个延迟点按 100 MHz 采样网格量化到最近样本，延迟量化误差小于 0.005 Tc。噪声按单位幅度复基带信号的每采样点 SNR 定义；固定随机种子以便复现。

## 实验内容

1. 比较本地多普勒估计为 1000 Hz 和 500 Hz 时，相关输出的 I、Q 分量及幅度。
2. 在载波初相误差为 0°、180° 时计算相干超前减滞后、非相干包络超前减滞后和超前减滞后功率三种鉴别器输出。
3. 在四种 SNR 下绘制三种鉴别器输出。

相关图为便于观察峰形，局部视图显示 ±2 Tc；MAT 文件保存完整 ±100 Tc 扫描数据。

## 文件

- `run_dll_experiment.m`：完整仿真和结果导出。
- `verify_dll_experiment.m`：MATLAB 验证脚本。
- `dll_simulation_results.mat`：完整仿真数据和参数。
- `dll_simulation_results.txt`：关键参数和数值摘要。
- `correlation_doppler_zoom.png`、`correlation_doppler_full_scan.png`：多普勒匹配/失配相关输出。
- `dll_discriminators_phase_0.png`、`dll_discriminators_phase_180.png`：两种载波初相下的鉴别器输出。
- `dll_discriminators_noise_snr.png`：四档 SNR 下的三种鉴别器输出。
