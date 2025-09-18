// LightweightCharts 3.8.0 简化版本 - 仅包含核心功能
// 这是一个简化的占位符，实际项目中应该使用完整的LightweightCharts库

window.LightweightCharts = {
    createChart: function(container, options) {
        console.log('Creating chart with options:', options);
        
        // 创建一个简单的Canvas图表占位符
        const canvas = document.createElement('canvas');
        canvas.width = options.width || container.offsetWidth;
        canvas.height = options.height || container.offsetHeight;
        canvas.style.width = '100%';
        canvas.style.height = '100%';
        canvas.style.background = options.layout?.backgroundColor || '#0d1421';
        
        container.appendChild(canvas);
        
        const ctx = canvas.getContext('2d');
        
        // 简单的图表对象
        const chartAPI = {
            addCandlestickSeries: function(seriesOptions) {
                console.log('Adding candlestick series:', seriesOptions);
                
                return {
                    setData: function(data) {
                        console.log('Setting candlestick data:', data);
                        
                        // 清除画布
                        ctx.clearRect(0, 0, canvas.width, canvas.height);
                        
                        // 绘制简单的K线占位符
                        ctx.fillStyle = '#ffffff';
                        ctx.font = '16px Arial';
                        ctx.textAlign = 'center';
                        ctx.fillText('K线图 (简化版)', canvas.width / 2, canvas.height / 2 - 20);
                        ctx.fillText(`数据点: ${data.length}`, canvas.width / 2, canvas.height / 2 + 20);
                        
                        // 绘制简单的价格线
                        if (data.length > 0) {
                            ctx.strokeStyle = '#4bffb5';
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            
                            data.forEach((item, index) => {
                                const x = (index / (data.length - 1)) * canvas.width;
                                const y = canvas.height - ((item.close - 40) / 60) * canvas.height;
                                
                                if (index === 0) {
                                    ctx.moveTo(x, y);
                                } else {
                                    ctx.lineTo(x, y);
                                }
                            });
                            
                            ctx.stroke();
                        }
                    }
                };
            },
            
            timeScale: function() {
                return {
                    fitContent: function() {
                        console.log('Fitting content to time scale');
                    }
                };
            },
            
            applyOptions: function(newOptions) {
                console.log('Applying chart options:', newOptions);
                if (newOptions.width) canvas.width = newOptions.width;
                if (newOptions.height) canvas.height = newOptions.height;
            }
        };
        
        return chartAPI;
    },
    
    CrosshairMode: {
        Normal: 0,
        Magnet: 1,
    }
};

console.log('LightweightCharts API loaded (simplified version)');