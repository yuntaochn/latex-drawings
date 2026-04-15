图片管理

USV 示意图

- 图 1 USV 坐标系与路径跟踪误差定义示意图
- 图 2 自适应 LOS 制导几何关系示意图
- 图 3 受约束 USV 自适应路径跟踪控制框架图
- 图 4 不同方法在典型路径下的轨迹跟踪结果
- 图 5 不同方法的横向误差变化曲线
- 图 6 不同方法的控制输入变化曲线

本地生成 PDF 和 SVG

执行：

```bash
./scripts/build_assets.sh
```

或：

```bash
make
```

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_assets.ps1
```

本地构建结果默认写入 `.local/output/`，不会覆盖仓库中的 `output/`。
在这个本地目录下，构建完成后会自动清理中间文件，只保留 `pdf/svg`。
默认会编译 `src/` 与 `drafts/` 下的所有 `.tex` 文件。
其中 `src/` 产物输出到 `.local/output/src/`，`drafts/` 产物输出到 `.local/output/drafts/`。
可通过 `SOURCE_NAMES` 指定要编译的目录，例如仅编译 `src`：`SOURCE_NAMES=src`。

如果需要显式写入 `output/`，可以先设置环境变量：

```powershell
$env:OUTPUT_DIR = "output"
powershell -ExecutionPolicy Bypass -File .\scripts\build_assets.ps1
```

可选：通过 `KEEP_INTERMEDIATES` 控制是否保留中间文件（支持 `0/1/true/false/yes/no`）：

```powershell
$env:OUTPUT_DIR = "output"
$env:KEEP_INTERMEDIATES = "0"
powershell -ExecutionPolicy Bypass -File .\scripts\build_assets.ps1
```

CI（GitHub Actions）默认设置为：`SOURCE_NAMES=src` 且 `OUTPUT_DIR=output`，只更新 `output/src/` 下产物。

依赖：

```bash
latexmk
xelatex
dvisvgm   # 推荐，TeX Live 通常自带
# 或 pdf2svg
```
