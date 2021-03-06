# Network Status Blockchain

### Datastructure:

$\mathcal{Q}_{\text{A}}$：
    
  待检查队列.

${\mathcal{Q}}^{\text{addr}}_{\text{A}}$: 

  与$\mathcal{Q}_{\text{A}}$同状态的有效账户$\text{addr}$的队列.

$\text{Action}$: 一个行为证明,可能是$\text{Attestaion}(\color{#B22222}{\text{Atte}})$或者$\text{MerkleProof}(\color{#B22222}{\text{Merk}})$.

### function:

##### constructor:

​	初始化一个状态,要求初始化为一个可行的状态。具体状态待讨论。

​	这里试运行的是初始状态是：

​		1. 必须要有至少一个人($Req$个人)作为初始账号

​		2. 在初始账号的基础上,当达到$Req$个人确认状态时,必须有$\displaystyle \lceil \frac{Req}{2} \rceil$个人认为有效才接受状态。

##### owner add/remove:

​	合约有效账户采取邀请制。如果邀请一个账户,当达到$Req$个人确认状态时,必须有$Req$个人认为该用户有资格才接受更改。如果踢出一个账户,当达到$Req$个人确认状态时,必须有$Req$个人认为该用户不合格才接受更改。

##### Action add/Verify:

​	增加一个请求验证的Action,是否需要一个来自哪个链的状态现在还未考虑。

​	一个Action被定义为：
$$
\text{Action}:= \begin{array}{rl}
(\mathsf{storagehash},\mathsf{key},\mathsf{val})&,\text{Action is a }\color{#B22222}{\text{Merk}}.\\
\mathrm{Cert}(\mathsf{content},\mathrm{Sig}^{X},\mathrm{Sig}^{Y})&,\text{Action is a }\color{#B22222}{\text{Atte}}.
\end{array}
$$
​	一个Action的映射函数被如下运算：


$$
\begin{aligned}\mathrm{Mapping}:\mathrm{keccak256}(\mathrm{bytes32}(\mathrm{keccak256}(\color{#B22222}{\text{Action}})\color{black})+\mathrm{bytes32}(\mathsf{slot}))\mapsto \color{#B22222}{\text{Action}}\end{aligned}
$$


​	当然我们只需要计算$\mathrm{keccak256}(\color{#B22222}{\text{Action}}\color{black})$.

##### Action get/vote



##### other api


#### bug fix:

1.getAction(): 

处理被删除的Action的时候没考虑指针右移越界的情况.
```
    ownersPointer[msg.sender] < waitingVerifyProof.length
```
2.addAction(Action action):

修改判断Action是否已存在的逻辑:

细节:d1aa37c38f3857d4fb958efd0fccbc2ced367ff2
```
    require(actionTree[keccakhash].storagehash == bytes32(0), "already in actionTree");
```
3.validVote(uint curPointer):

细节:d1aa37c38f3857d4fb958efd0fccbc2ced367ff2

更改合法vote右区间端点的逻辑为:
```
    require(curVotedPointer < ownersPointer[addr], "no Action to vote");
```
4.removeOwner(address _removeOwner):

细节:d1aa37c38f3857d4fb958efd0fccbc2ced367ff2

修改删除合法账号的逻辑:
```
    if (vote_count >= requiredOwnerCount) {
            isOwner[_removeOwner] = false;
            for (uint j = 0; j < owners.length; j++) {
                if (owners[j] == _removeOwner) {
                    owners[j] = owners[owners.length - 1];
                    break;
                }
            }
            owners.length -= 1;
        }
```
5.voteProof(bool validProof):

细节:fb0d84254693f131469282fcd1eb488e99504923

指针多移了一次.
处理被删除的Action的时候没考虑指针右移越界的情况.
```
    while(votedPointer < waitingVerifyProof.length && 
            waitingVerifyProof[votedPointer] == 0)votedPointer ++;
```
