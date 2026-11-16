# ADR 0028: Names and generations (P4.17)

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records. The owner judges by playtest.
- Scope: how people are named, the name pools, the names the game must never produce, how a family changes from one generation to the next, and the first-launch surname step.

## Why this needs a decision

The checklist gives the shape: surname plus a generated given name, era pools keyed by generation, a blocklist of famous historical figures, personality drift, and a surname step on first launch. It leaves the pools, the blocklist, the drift numbers and the edge cases to be decided.

## Naming

- A person is a given name and a surname, shown given name first in pinyin without tone marks: "Jianguo Wang". At the table, in the epilogue and in the history a villager is called by surname alone, as today. The full name is shown where a person is introduced: the dossier, the Quota page's "At the table" line, the run setup page (the player's own name), and the ending page's heading line.
- Given names are drawn when a run starts, on a stream of their own (`names`), so naming a run moves no deal, bid or event: one for the player and one for every family in the roster. A sent-down youth gets one when they arrive. A run never holds two people with the same full name, and never two with the same given name either, so a name alone identifies a person.
- Names are stored in the run save. The profile keeps only the surname the player chose.
- Nothing in the game states or implies a person's gender. The pools mix names of every kind and a name is never tied to a portrait.

## Era pools

The pool is chosen by the generation, which goes up by one with every run the family starts. The village does not age with it: the names move on while the brigade office, the Quotas and the table stay as they were. That is deliberate.

| Generations | Pool | The names read as |
| --- | --- | --- |
| 1 | Old | Given before the founding of the People's Republic: luck, wealth, flowers, and rustic names of the kind that began as milk names and stuck |
| 2 | Founding | The 1950s: building the country, peace, the Korean War, the Great Leap |
| 3 | Red | The 1960s and 1970s: red, east, the army, the Cultural Revolution |
| 4 and later | Reform | The 1980s and 1990s, when one-syllable and doubled given names were in fashion |

From generation 5 the Reform pool stays in use. Two-syllable names came back into favour after 2000; a fifth pool for those belongs to the second content wave (P4.20).

**Old.** Fugui, Youcai, Changgui, Laifu, Desheng, Shuigen, Jinbao, Yongfu, Changshun, Tiezhu, Dashan, Shuanzhu, Mancang, Changfa, Fusheng, Laixi, Shunfa, Maosheng, Genfa, Erhu, Shitou, Dazhu, Xiaoman, Guilan, Xiulan, Yulan, Shuzhen, Guiying, Xiuying, Cuihua, Chunhua, Lanying, Guihua, Yuzhen, Suzhen, Shulan, Guizhi, Fengying, Baozhu, Jinfeng.

**Founding.** Jianguo, Jianhua, Guoqing, Jiefang, Xinhua, Jianjun, Heping, Yuanchao, Kangmei, Xinmin, Jianmin, Guoqiang, Aiguo, Aimin, Xinsheng, Fanshen, Jianshe, Guangrong, Shengli, Baoguo, Weiguo, Lixin, Minzhu, Huping, Aihua, Guohua, Jianping, Yongjun, Weimin, Jianxin, Xianjin, Yuejin, Chaoying, Chaomei, Gangtie, Weixing, Gonghe, Liqun, Qunying, Hezuo.

**Red.** Weidong, Xiangdong, Hongwei, Weihong, Yonghong, Wenge, Hongbing, Weibing, Jihong, Xuejun, Xuenong, Xuegong, Zhihong, Hongjun, Aihong, Jiange, Hongmei, Hongying, Hongyan, Hongxia, Dongfang, Chaoyang, Xiangyang, Hongxing, Hongtao, Yongge, Changzheng, Fanxiu, Weiwu, Dongsheng, Hongguang, Yanhong, Lihong, Xiaohong, Jianhong, Hongqi, Hongbo, Wenhua, Weiqun, Hongyu.

**Reform.** Wei, Lei, Jing, Yan, Na, Fang, Min, Jun, Tao, Chao, Bo, Ming, Juan, Ting, Xue, Hui, Yang, Kai, Hao, Xin, Dan, Yu, Qiang, Bin, Jie, Ping, Xia, Mei, Yong, Liang, Tingting, Lili, Dandan, Jingjing, Xiaoming, Xiaoli, Xiaoyan, Haitao, Zhiqiang, Haiyan.

Each pool holds 40 names, and a run names at most about 20 people.

## Names the game never produces

Two lists, both data. A draw takes one name from those of the pool that nobody in the run holds and that neither list blocks with the person's surname, so a blocked name is never drawn at all. A pool with no such name left hands on to the next pool, and the last hands on to the first.

**Given names blocked with every surname.** Some of these point at one person by themselves and some are ordinary names; blocking all of them everywhere is the cautious choice, and costs nothing: Zedong, Enlai, Xiaoping, Shaoqi, Dehuai, Guofeng, Ziyang, Yaobang, Jieshi, Zhongshan, Zemin, Jintao, Jinping, Keqiang, Jiabao, Rongji, Chunqiao, Wenyuan, Hongwen, Anying, Yonggui, Jinxi, Hulan, Yulu, Cunrui, Jiguang, Shaoyun, Hongchang, Junchang, Xiangqian, Yingchao, Guangmei.

**Full names blocked as a pair** (surname, given name), for short or common given names:

- Leaders and officials: Lin Biao, Zhu De, Chen Yun, Chen Yi, Chen Boda, Kang Sheng, Jiang Qing, Gao Gang, He Long, Peng Zhen, Li Peng, Wan Li, Ye Jianying, Li Xiannian, Liu Bocheng, Nie Rongzhen, Luo Ronghuan, Luo Ruiqing, Yang Shangkun, Wang Zhen, Wang Dongxing, Bo Yibo, Tao Zhu, Xie Fuzhi, Tan Zhenlin, Ke Qingshi, Li Jingquan, Zeng Xisheng, Wu Zhipu, Mao Yuanxin.
- Before 1949: Sun Wen, Sun Yixian, Jiang Zhongzheng, Jiang Jingguo, Song Qingling, Song Meiling, Wang Jingwei, Zhang Xueliang, Yuan Shikai.
- Model workers, soldiers and other public figures: Lei Feng, Wang Jie, Shi Chuanxiang, Xing Yanzi, Zhang Zhixin, Lin Zhao, Yu Luoke, Nie Yuanzi, Kuai Dafu, Song Binbin.
- Writers, by the names they are known by: Lu Xun, Guo Moruo, Ba Jin, Lao She, Cao Yu.
- Founders, leaders and others a second pass found missing: Chen Duxiu, Li Dazhao, Ren Bishi, Zhang Wentian, Dong Biwu, Deng Zihui, Zhang Zhongliang, Shu Tong, Wang Renzhong, Wei Guoqing, Zhang Side, Yang Gensi, Luo Shengjiao, Peng Pai, Bian Zhongyun.
- Names the pools can produce with a surname the game uses, found by checking every such pairing: Wang Ming, Wang Ping, Wang Fang, Wang Jun, Wang Yang, Wang Tao, Li Desheng, Li Xiuying, Li Jianguo, Li Yuanchao, Li Qiang, Li Tao, Li Jing, Li Yan, Li Min, Li Ming, Li Heping, Li Baoguo, Li Dongsheng, Zhao Guilan, Zhao Dan, Sun Yong, Sun Jun, Chen Yu, Chen Bo, Chen Lei, Chen Hui, Chen Xin, Chen Jie, Chen Yan, Chen Qiang, Chen Yong, Liu Yongfu, Liu Wei, Qin Hui, Qin Guangrong, Gao Yang, Xu Xin, Xu Tao, Zhou Yang, Zhou Hui, Ma Jun, Ma Hui, Feng Yong, Tang Liang, Tang Tao, Deng Liqun, Hu Ping, Hu Wei, Lin Wei, Lin Xiangyang, Guo Bo, Song Ping, Xie Fang, Xie Liang, Xie Xuegong, Han Jun, Yang Kai, Yang Bo, Yang Yong, Peng Bo, Zhang Fugui, Zhang Guohua, Zhang Hao, Zhang Wei, Zhang Bo, Zhang Jun, Zhang Ping, Zhang Yang, Zhang Chao, Huang Jing, Huang Wei, He Weidong, He Hongjun, Dong Jun, Tian Guiying, Tian Fang, Pan Fusheng.

The first list also covers the two Xiaogang farmers the game's historical note rests on (Hongchang, Junchang), and the best-known model workers and soldiers. A test checks that no pool name is on the first list. Living entertainers and athletes are out of scope: the list is for the people the game's history touches. It cannot be complete: with common surnames and short given names, some generated name will always belong to somebody. The lists were checked once against sources (2026-11-15) and are data, so a name a player reports is one line to add.

## From one generation to the next

- **What stays.** A family keeps its surname, its place in the village, its memory of the player's family (which fades, as today) and its personality.
- **What drifts.** A family's personality is five levels: bomb aggression, cooperation, honesty, ambition and grudge. Each generation, each of the five moves one level, up or down with equal chance, with a probability of 15% (data), and stays within the scale of low, mid and high. With three levels that is slow on purpose: a family is recognisably itself for several generations. A family's bot tier does not drift. The drift is kept in the profile as an offset per family and trait, so it accumulates, and it is drawn on a stream seeded from the generation's number so the same profile always produces the same village. The first generation is the village as it is defined; drift starts with the second. Every village family is drawn for, in the book's order, whether or not the profile has unlocked it, so unlocking a family never changes another's drift. The drift is copied into the run when it starts, so a saved run keeps the village it began with.
- **The voice** drifts too: each generation shifts a family's base pitch by up to 4% either way (data), from the same stream, never more than 12% from the family's own voice. The letters of a voice are rendered ahead of time, so the shift is applied when a line is played and never to the rendered bank.
- Sent-down youth have no generations: each is new.

## The surname step

On first launch, after the content note and before the Arrival page: one page.

- "Your family's name" with a text field (1 to 12 Latin letters; the first is capitalised, the rest lowered; no spaces, digits or marks), a row of 24 common surnames as tickets, and a **Random** button that picks one of them.
- The 24: Zhang, Yang, Huang, Wu, Lin, Zhu, He, Guo, Luo, Song, Xie, Han, Cao, Peng, Hu, Jiang, Cai, Ding, Shen, Ye, Tian, Pan, Yuan, Dong. None is a roster family's surname.
- A surname that a village family holds (Wang, Li, Zhao, Sun, Chen, Liu, Qin, Gao, Xu, Zhou, Ma, Feng, Tang, Deng) is refused: "The {name} family already lives here." A sent-down youth who would share the player's surname is given another.
- The page opens with the field focused and a default already in it, so one press of Confirm is enough.
- The surname is held until the tutorial ends or is skipped and is written with the profile's first save (ADR 0026). **Settings** shows it and can change it between runs, on the same page; while a run is saved or the arrival is playing it says so instead.
- The player's given name is drawn each run like everyone else's, and is never one that, with the chosen surname, is on the blocked lists.

## Consequences

- The profile gains the per-family drift, which changes its shape: it moves to schema 3 with a migration.
- The run save gains the given names and the drift: it moves to schema 15 with a migration that names a saved full run from its seed and generation, the same way every time, under the surname Zhang, the only one a profile could hold before this, and with no drift.
- A run started without a profile (the balance harness, tests) is named by the surname its request carries, or Zhang, from the first pool, and has no drift. No sent-down youth is called Zhang, so the harness's event draws are as they were.
- A player whose surname is one of the twelve the youth use never meets a youth of that name, which changes which youth arrive in those runs.
- `player.surname`, the placeholder, goes away.
- A test simulates 10,000 runs across generations 1 to 6 and finds no duplicate name within a run and no blocked name, including with every listed surname as the player's.
