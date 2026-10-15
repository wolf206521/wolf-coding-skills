# 统一语言词汇表模板

文件：`docs/<project>/glossary.md`

```markdown
# 统一语言词汇表

| 中文术语 | 英文标识符 | 定义 | 所属上下文 | 别名/歧义 | 来源 |
| --- | --- | --- | --- | --- | --- |
| 报价单 | Quotation | 面向客户的价格方案，含工艺与价格明细 | quotation | 与 salesOrder 区分 | 需求 REQ-QUOTATION-001 |
| 拼版方案 | Imposition | 成品尺寸 → 大版/开纸的排样结果 | prepress | — | master-plan §4.2 |
| 损耗 | Waste / 放损 | 印刷过程中的额外用料比例 | craft | 口径按克重/印工区分 | 行业手册 |
```

规则：

- **英文标识符**是代码里的唯一来源（类名/字段/事件名），中文是文档表述。
- 同名不同义必须分列两行，标注所属上下文（如 `order` 的"订单" vs `outsourcing` 的"外协单"）。
- 每个术语标注来源，保证可追溯；新增术语先改本表，再改代码。

## 印刷行业样例术语（起步参考）

报价 Quotation、销售订单 SalesOrder、生产工单 WorkOrder、工艺卡 CraftSheet、拼版方案 Imposition、纸张库存 PaperStock、外协单 OutsourcingOrder、采购单 PurchaseOrder、质检单 QualityCheck、发运单 Shipment、对账单 Statement、成本单 CostSheet。
