# kaikai 高效编程

(书名原文:*Programación efectiva con kaikai* / *Effective
Programming with kaikai*。"效"字在这里一语双关:既指**高效**
(effective)的编程,也指语言核心的代数**效应**(effects)——
原文里 efectiva/efectos、effective/effects 的双关,中文借同一个
"效"字保留。)

一本关于 [kaikai](https://github.com/kaikailang-org/kaikai)
的书。kaikai 是一门函数式、静态类型的程序设计语言,把代数效应
(algebraic effects)作为一等公民,提供 Elixir 风格的 pipeline,
通过 LLVM 编译为原生代码,内存模型基于 Perceus 引用计数加上隔离
的 BEAM 风格 fiber——没有垃圾收集器,也没有 borrow checker。

作者:Eduardo Díaz([lnds](https://github.com/lnds))。

本文档其他语言版本:[English](./README.md) · [Español](./LEEME.md)。

## 这本书是什么

一本**用来读的书**,不是参考手册。语言的参考文档放在
[`kaikai/docs`](https://github.com/kaikailang-org/kaikai/tree/main/docs)。
本书是与参考文档互补的长篇读物:每一章都解释设计背后的*为什么*,
从第一页开始就带读者走过可以运行的程序。

结构灵感来自 Donovan 和 Kernighan 的 *The Go Programming
Language*:文字密实,程序从第一章就是真实可运行的代码,关键章节
以综合性的案例研究收尾,每章末尾配有练习。讲解风格灵感来自
Miran Lipovača 的 *Learn You a Haskell for Great Good!*:在新概念
出现时语气温和,概念循序渐进引入,留出让读者喘息的余地。

语气是作者本人的,不是上面两本的复制。在合适的地方用第一人称;
该有立场的地方就有立场。语言是作者设计的,这本书也站在它一边。

## 读者对象

一名**有经验**的程序员——熟悉某种命令式或面向对象的语言(Python、
Go、Java、JavaScript、C#、Rust 都算),但**未必接触过函数式
语言**。书中遇到代数数据类型(ADT)、pattern matching、默认不可变
性、effects-in-types 这类概念时,会从读者已经熟悉的东西出发搭桥,
而不是默认你已经懂。

如果你已经熟悉 Haskell、OCaml、Elixir 或 Scala,前几章可以快速
浏览;真正有区分度的内容在第三部分(effects、fibers、actors、
holes 与 LLM 协作)。

本书**不是**面向编程零基础读者的。读者需要已经知道什么是函数、
类型、列表、测试。

## 关于版本

本书目前提供两个**同等地位**的版本,二者互相**不是**对方的翻译,
而是用各自语言原生写就:

- **西班牙语**版 —— 章节在 `capitulos/`,示例代码在
  `ejemplos/`。语气以作者的[博客](https://lnds.net)为基准校准。
- **英语**版 —— 章节在 `chapters/`,示例代码在 `examples/`。
  语气以 `kaikai/docs/` 中的设计文档及相关技术写作为基准校准。

代码示例与对应语言绑定:字符串字面量、注释和文件名使用该版本
所用的自然语言。标识符、语言关键字以及 kaikai 标准库的 API 名称
始终保持原始形式(英文)。当图表与语言无关时,集中放在 `figuras/`
共用。

关于"版本"一词的说明:kaikai *语言*本身也有 edition(纪元)——
Tongariki、Hanga Roa、Orongo,以及地平线上的 Anakena——这是它的
稳定性机制(第 16 章有介绍)。本书基于 **Hanga Roa** 纪元撰写并
验证,当前对应 **kaikai 0.111.0**。语言的里程碑按纪元划定,而不是
按版本号:Hanga Roa 已经走过 0.100.x 系列而未更换纪元,Orongo 只在
其范围收敛时才会发布,路线图上**没有**"1.0"这个里程碑。

## 关于中文版

**目前本书还没有官方的中文版**。

这一页(`README.zh-CN.md`)是一份说明,而不是中文版本身。如果你
用中文阅读这一段,这意味着你比 README 看到的更多——但完整的图书
内容,目前只能在西班牙语和英语两个版本里找到。

我们(作者本人不是中文母语者)不打算把现有版本机器翻译成中文,
然后冠以"中文版"的名义出版。原因与书名里的"效"字一脉相承:
书的开头引用了德鲁克的名言——效率是正确地做事,效能是做正确
的事。机器翻译一个中文版,*效率*很高,却不是正确的事——它会
让中文读者读到一位**没有口音的作者**,这恰好与本书的精神相反。

### 我们在寻找的协作方式

如果你:

- 母语是中文(简体或繁体均可),
- 对 kaikai 的设计有兴趣,
- 愿意像作者撰写西班牙语版那样,**用中文重写**(而不是翻译)
  其中的若干章节,把作者的论点用符合中文阅读习惯的方式表达
  出来,

欢迎在 [issue 区](https://github.com/kaikailang-org/kaikai-book/issues)
留言。我们更希望中文版**与现有版本并列**,而不是从属于它们。

### 临时建议

在中文版出现之前,如果你想用中文了解 kaikai,几个可行的入口:

- 阅读语言本身的[设计文档](https://github.com/kaikailang-org/kaikai/tree/main/docs)。
  这部分主要是英文,但术语集中、上下文清楚,容易借助翻译工具
  阅读。
- 直接阅读英语版的本书(从 `chapters/ch01-tour.md` 开始)。kaikai
  的术语在中文程序员圈里通常按英文原样使用(`pattern matching`、
  `effect`、`fiber`、`hole`、`protocol`),不必逐字翻译就能读懂。
- 关注本仓库的 release 页面,获取 PDF 版本:
  [Releases](https://github.com/kaikailang-org/kaikai-book/releases)。

## 仓库结构

```
CLAUDE.md             — 协作智能体的工作说明
estructura.md         — 完整目录(19 章 + 6 个附录)
capitulos/            — 西班牙语版章节,文件名格式 capNN-*.md
chapters/             — 英语版章节,文件名格式 chNN-*.md
ejemplos/capNN/       — 西班牙语版引用的示例源码
examples/chNN/        — 英语版引用的示例源码
figuras/              — 图表与图片(与语言无关时共用)
borradores/           — 还没成稿的笔记和原始素材
README.md             — 英文 README
LEEME.md              — 西班牙语 README
README.zh-CN.md       — 本文件
```

## 构建与运行示例

需要安装 `kai` 编译器。在 kaikai 语言仓库下:

```sh
cd /path/to/kaikai
make all
```

把 `kai` 加入 `PATH` 之后,本书中的所有示例都可以直接运行:

```sh
kai run examples/chNN/<file>.kai     # 英语版的示例
kai run ejemplos/capNN/<file>.kai    # 西班牙语版的示例
```

每个示例都对当时所用的 `kai` 版本做过验证。当某个示例依赖最近
修复的 bug 时,对应的章节 commit 会在说明里写明版本号。

## 进度

仍在写作中。本书按章顺序撰写,从第 1 章开始。完整规划见
`estructura.md`,实际进度见 `git log`。

## 许可证

待定。文字部分与代码示例最终可能采用不同的许可证(文字部分
倾向于 CC-BY-SA,代码部分倾向于 MIT 或相近的许可证)。

## 联系方式

欢迎在本仓库提 issue 或 pull request。
关于**语言本身**(而不是这本书)的反馈,请到
[kaikailang-org/kaikai](https://github.com/kaikailang-org/kaikai)。
