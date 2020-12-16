---
title: "结构体及其方法"
date: 2020-12-16T09:10:06+08:00
toc: true
isCJKLanguage: true
tags: 
  - Go
---

## 结构体类型基础知识

结构体表示的是实实在在的数据结构。一个结构体类型可以包含若干个字段，每个字段通常都需要有确切的名字和类型。

结构体也可以不包含任何字段，我们还可以为类型关联上一些方法，这里可以把方法看成是函数的特殊版本。

函数是独立的程序实体。可以声明有名字的函数，也可以声明没名字的函数，还可以把函数当成普通的值传来传去。可以把具有相同签名的函数抽象成独立的函数类型，作为一组输入、输出（或者说一类逻辑组件）的代表。

方法却不同，它需要有名字，不能被当做值来看待，最重要的是，它必须隶属某一个类型。方法所属的类型会通过其声明中的接收者（receiver）声明体现出来。

接收者声明就是关键字 `func` 和方法名称之间的圆括号包裹起来的内容，其中必须包含确切的名称和类型字面量。

接收者的类型就是当前方法所属的类型，接收者的名称就是在当前方法中引用它所属类型的当前值。

```go
// AnimalCategory 代表动物分类学中的基本分类法。
type AnimalCategory struct {
	kingdom string // 界。
	phylum  string // 门。
	class   string // 纲。
	order   string // 目。
	family  string // 科。
	genus   string // 属。
	species string // 种。
}

func (ac AnimalCategory) String() string {
  return fmt.Sprintf("%s%s%s%s%s%s%s",
    ac.kingdom, ac.phylum, ac.class, ac.order,
    ac.family, ac.genus, ac.species)
}
```

结构体类型 `AnimalCategory` 代表了动物的基本分类法，其中有 7 个 `string` 类型的字段，分别表示各个等级的分类。

下边有个名叫 `String` 的方法，从它的接收者声明可以看出它隶属于 `AnimalCategory` 类型。

通过该方法的接收者名称 `ac`，我们可以在其中引用到当前值的任何一个字段，或者调用到当前值的任何一个方法（也包括 `String` 方法自己）。

这个 `String` 方法的功能是提供当前值的字符串表示形式，其中的各个等级分类会按照从大到小的顺序排列。使用时，我们可以这样表示：

```go
category := AnimalCategory{species: "cat"}
fmt.Printf("The animal category: %s\n", category)
```

这里，我用字面量初始化了一个 `AnimalCategory` 类型的值，并把它赋给了变量 `category`。为了不喧宾夺主，我只为其中的 `species` 字段指定了字符串值"cat"，该字段代表最末级分类“种”。

在 `Go` 语言中，我们可以通过为类型编写名为 `String` 的方法，来自定义该类型的字符串表示形式。这个 `String` 方法不需要任何参数声明，但需要一个 `string` 类型的结果声明。

> 方法隶属的类型并不局限于结构体类型，但必须是某个自定义的数据类型，而且不能是任何接口类型。
>
> 一个数据类型关联的所有方法，共同组成了该类型的方法集合。同一个方法集合中的方法不能出现重名。如果它们所属的数据类型是结构体，那面它们的名称和该类型中的任何字段也不能重名。
>
> 结构体的字段是它的一个属性或者一项数据，隶属它的方法是附加在其数据上的一项操作或者能力。将属性及其能力封装在一起是面向对象的一个主要原则。
>
> `Go` 语言摄取了面向对象编程中的很多优秀特性，同时也推荐这种封装的做法。从这方面看，`Go` 语言是支持面向对象编程的，但它选择摒弃了一些在实际运用过程中容易引起程序开发者困惑的特性和规则。

## 结构体类型的嵌套

```go
type Animal struct {
	scientificName string // 学名。
	AnimalCategory        // 动物基本分类。
}
```

`Go` 语言规范规定，如果一个字段的声明中只有字段类型名而没有字段名称，那么它就是一个嵌入字段，也被称为匿名字段。可以通过此类型变量名跟 `.`，再跟嵌入字段类型的方式引用到该字段，也就是说，嵌入字段的类型既是类型也是名称。

```go
func (a Animal) Category() string {
	return a.AnimalCategory.String()
}
```

在某个代表变量的标识符右边加 `.`，再加上字段名或方法名的表达式被称为选择表达式，它用来表示选择了该变量的某个字段或方法。

嵌入字段的方法集合会被无条件的合并进被嵌入类型的方法集合中：

```go
animal := Animal{
    scientificName: "American Shorthair",
    AnimalCategory: category,
}
fmt.Printf("The animal: %s\n", animal)
```

这里并没有给 `Animal` 编写 `String` 方法，但是是没问题的，嵌入字段 `AnimalCategory` 的 `String` 方法会被当做 `animal` 的方法调用。