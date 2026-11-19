import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

BG="#E9EBE8"; DK="#163A1E"; MID="#3D7A47"; LT="#D6E4D3"; WH="#FFFFFF"; GR="#6B7A6D"
fig=plt.figure(figsize=(16,7.6),dpi=120); fig.patch.set_facecolor(BG)
ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,160); ax.set_ylim(3,79); ax.axis("off")
T="Georgia"; S="Segoe UI"

def box(x,y,w,h,title,sub="",fill=WH,edge=DK,tc=DK,lw=2,ts=17,ss=12.5,ls="-"):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0,rounding_size=1.6",fc=fill,ec=edge,lw=lw,ls=ls))
    if sub:
        ax.text(x+w/2,y+h*0.64,title,ha="center",va="center",fontsize=ts,family=T,color=tc,weight="bold")
        ax.text(x+w/2,y+h*0.30,sub,ha="center",va="center",fontsize=ss,family=S,color=tc,linespacing=1.35)
    else:
        ax.text(x+w/2,y+h/2,title,ha="center",va="center",fontsize=ts,family=T,color=tc,weight="bold")

def arrow(p,q,label="",lp=None,both=False,color=DK,ha="center",cs="arc3"):
    ax.add_patch(FancyArrowPatch(p,q,arrowstyle=("<|-|>" if both else "-|>"),mutation_scale=18,lw=2,color=color,connectionstyle=cs,shrinkA=0,shrinkB=0))
    if label:
        lx,ly=lp if lp else ((p[0]+q[0])/2,(p[1]+q[1])/2+1.6)
        ax.text(lx,ly,label,ha=ha,va="center",fontsize=11.5,family=S,color=GR)

def tag(x,y,n):
    ax.add_patch(plt.Circle((x,y),1.9,color=DK,zorder=5))
    ax.text(x,y-0.1,n,ha="center",va="center",fontsize=13,family=T,color=WH,weight="bold",zorder=6)


# Peripheral container
ax.add_patch(FancyBboxPatch((46,16),110,58,boxstyle="round,pad=0,rounding_size=2",fc=LT,ec=MID,lw=2,ls=(0,(6,4))))
ax.text(49,70.5,"alarm_clock_io",fontsize=19,family=T,color=DK,weight="bold",va="center")
ax.text(49,67,"SCOMP peripheral  ·  I/O addresses 0x070 – 0x077",fontsize=12.5,family=S,color=DK,va="center")

# SCOMP
box(4,34,28,26,"SCOMP","CPU, 10 MHz clock\nruns alarm_demo.asm\nIN / OUT instructions",ts=20)
tag(6.5,57.5,"4")
# base IO
box(4,8,28,14,"Board I/O","Switches · LEDs · 7-seg\n0x000 – 0x005",ts=15)

# Bus: SCOMP <-> alarm peripheral
arrow((32,47),(50,47),both=True)
ax.text(41,49.5,"I/O bus",fontsize=13,family=T,color=DK,ha="center",weight="bold")
ax.text(39.5,44.5,"0x070–0x077",fontsize=10.5,family=S,color=GR,ha="center",va="center")
# SCOMP <-> board I/O (SCOMP drives LEDs / 7-seg itself)
arrow((18,34),(18,22),both=True)
ax.text(20,28,"IN / OUT",fontsize=11.5,family=S,color=GR,va="center")

# Inside
box(50,30,26,30,"Bus Interface","address decode\nregister read / write\nBCD input check\ntri-state IO_DATA",ts=16)
tag(52.5,57.5,"3")
box(88,52,28,13,"Clock Divider","10 MHz → 1 Hz tick\n×60 in fast mode",ts=15)
tag(90.3,62.6,"1")
box(88,26,28,17,"Time Counter","BCD  HH:MM:SS\nrollover 23:59:59 → 00:00:00",ts=15)
tag(90.3,40.6,"1")
box(124,26,28,17,"Alarm Logic","compare time = alarm\nring state machine",ts=15)
tag(126.3,40.6,"2")

arrow((76,56),(88,58.5),"FAST",lp=(81.5,59.5))
arrow((102,52),(102,43),"tick",lp=(105,47.5))
arrow((76,38),(88,38),"set time",lp=(82,40.3),both=False)
arrow((88,31),(76,31),"read time",lp=(82,33.2))
arrow((116,34.5),(124,34.5),"time",lp=(120,36.8))
# bus <-> alarm, routed under
ax.plot([63,63,138,138],[30,21,21,26],color=DK,lw=2)
ax.add_patch(FancyArrowPatch((138,22),(138,26),arrowstyle="-|>",mutation_scale=18,lw=2,color=DK,shrinkA=0,shrinkB=0))
ax.add_patch(FancyArrowPatch((63,22),(63,30),arrowstyle="-|>",mutation_scale=18,lw=2,color=DK,shrinkA=0,shrinkB=0))
ax.text(100,23,"alarm time · enable · reset  →    ←  ringing status",fontsize=11.5,family=S,color=GR,ha="center",va="center")

# Ringing output
box(124,6,28,7,"LED / buzzer",ts=14,fill=WH)
ax.plot([148,148],[26,16],color=DK,lw=2)
ax.add_patch(FancyArrowPatch((148,17),(148,13),arrowstyle="-|>",mutation_scale=18,lw=2,color=DK,shrinkA=0,shrinkB=0))
ax.text(146.5,19.5,"RINGING",fontsize=11.5,family=S,color=GR,va="center",ha="right")

# Verification note
ax.add_patch(FancyBboxPatch((50,6),68,7,boxstyle="round,pad=0,rounding_size=1.4",fc=BG,ec=GR,lw=1.5,ls=(0,(4,3))))
tag(53.5,9.5,"5")
ax.text(57,9.5,"Testbenches simulate each module in ModelSim before board testing",fontsize=12,family=S,color=DK,va="center")

fig.savefig(sys.argv[1],facecolor=BG)
