/*
  2004WM 官网配置文件
  更改后无需改动 index.html/app.js。新增区服只需往 servers 数组中新增对象。
  共用账号、下载地址不随区服切换；排行榜必须配置各自真实接口。
*/
window.SITE_CONFIG = {
  siteName: '2004WM经典服',
  siteDomain: '2004wm.com',
  slogan: '山海相逢，故梦长开',
  qqNumber: '929090661',
  qqUrl: 'https://qm.qq.com/q/XyJf39bFEk',
  registerUrl: 'http://1.15.151.97:84/zc/',
  downloadUrl: 'https://1837633038.cdn.123clouddisk.com/1837633038/43714037#',
  // 不要把二区排行指向一区接口；未知时留空，网页会显示待接入。
  // 当前仓库没有排行服务，两区均留空；确认真实接口后分别填写。
  servers: [
    {id:'shanhai', code:'一区', name:'山海长歌', tag:'经典一区',
      slogan:'山海不老，长歌未央', cover:'assets/world.webp',
      rankApi:'', rankPage:''},
    {id:'shanhe', code:'二区', name:'山河故梦', tag:'经典二区',
      slogan:'山河依旧在，故梦待君归', cover:'assets/moments.webp',
      rankApi:'', rankPage:''}
  ],
  initialServer: 'shanhai'
};
