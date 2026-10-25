using System;using System.Drawing;using System.Drawing.Drawing2D;using System.Windows.Forms;
public class SuiteBackdrop:Panel {
 public SuiteBackdrop(){DoubleBuffered=true;BackColor=Color.FromArgb(37,45,63);}
 protected override void OnPaintBackground(PaintEventArgs e){using(var b=new LinearGradientBrush(ClientRectangle,Color.FromArgb(13,35,45),Color.FromArgb(62,65,88),75f)){e.Graphics.FillRectangle(b,ClientRectangle);}using(var p=new Pen(Color.FromArgb(20,180,191,193),1)){for(int y=20;y<Height;y+=29)e.Graphics.DrawLine(p,0,y,Width,y-40);}}
}
public class GoldButton:Button {
 public GoldButton(){FlatStyle=FlatStyle.Flat;ForeColor=Color.FromArgb(255,227,138);Cursor=Cursors.Hand;}
 protected override void OnPaint(PaintEventArgs e){var r=ClientRectangle;r.Width--;r.Height--;if(r.Width<2||r.Height<2)return;using(var b=new LinearGradientBrush(r,Enabled?Color.FromArgb(80,103,128):Color.FromArgb(55,58,64),Color.FromArgb(27,37,54),90f))e.Graphics.FillRectangle(b,r);using(var p=new Pen(Enabled?Color.FromArgb(223,181,75):Color.Gray,2))e.Graphics.DrawRectangle(p,1,1,r.Width-2,r.Height-2);TextRenderer.DrawText(e.Graphics,Text,Font,r,Enabled?ForeColor:Color.Silver,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);}
}
public class GoldTabs:TabControl {
 public GoldTabs(){DrawMode=TabDrawMode.OwnerDrawFixed;ItemSize=new Size(57,25);SizeMode=TabSizeMode.Fixed;Padding=new Point(0,0);}
 protected override void OnDrawItem(DrawItemEventArgs e){var r=GetTabRect(e.Index);using(var b=new LinearGradientBrush(r,e.Index==SelectedIndex?Color.FromArgb(93,112,139):Color.FromArgb(43,55,75),Color.FromArgb(25,35,53),90f))e.Graphics.FillRectangle(b,r);using(var p=new Pen(Color.FromArgb(222,181,71),1))e.Graphics.DrawRectangle(p,r.X+1,r.Y+1,r.Width-3,r.Height-3);TextRenderer.DrawText(e.Graphics,TabPages[e.Index].Text,Font,r,Color.FromArgb(255,227,137),TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);}
}
