# Huazhong University of Science and Technology (HUST): Space Communication Systems Experiment Design

## 伪码生成与相关特性仿真

本实验根据《伪码生成原理与仿真》课件中的 10 级线性反馈移位寄存器结构，生成 m 序列，并计算周期自相关和互相关。

## 运行环境

- MATLAB R2025a 或更新版本
- 仅使用 MATLAB 基础功能，不依赖额外工具箱

## 运行方法

在 MATLAB 当前文件夹切换到本目录后运行：

```matlab
run('m_sequence_simulation.m')
```

脚本会在本目录生成两张相关曲线图和一份结果摘要。执行过程中会检查序列周期、平衡性、自相关值和互相关峰位；若结果不符合预期，脚本会通过断言报错。

## 实验参数与结果

| 项目 | 设置或结果 |
| --- | --- |
| 生成多项式 | `1 + x^2 + x^3 + x^6 + x^8 + x^9 + x^10` |
| 寄存器级数 | 10 |
| 初始状态 | 全 1 |
| 最大周期 | `2^10 - 1 = 1023` 码片 |
| 双极性映射 | `0 -> +1`，`1 -> -1` |
| 周期自相关 | 零延迟为 1023，其余延迟为 -1 |
| C1/C2 循环移位 | 320 码片，按脚本所用延迟方向 |
| 互相关峰值 | 1023，峰位为 320 码片 |

## 文件说明

- `m_sequence_simulation.m`：生成两种结构的序列、计算相关并输出图表和摘要。
- `m_sequence_autocorrelation.png`：C1、C2 的周期自相关曲线。
- `m_sequence_cross_correlation.png`：C1、C2 的周期互相关曲线。
- `m_sequence_results.txt`：本次 MATLAB 运行的关键参数和数值结果。

相关函数采用 `Rxy(k) = sum_n x(n) * y(n-k)` 的循环延迟约定。改变输出端定义或延迟正方向会改变报告的峰位编号，但不会改变相关峰值。
