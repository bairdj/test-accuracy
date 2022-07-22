library(shiny)
library(ggplot2)
source("./evidence_strength_plot.R")
source("./network_flow.R")

# Define UI for application that draws a histogram
ui <- fluidPage(
  # Application title
  titlePanel("Diagnostic Test Accuracy"),
  
  flowLayout(
    sliderInput(
      "specificity",
      "Specificity",
      0,
      100,
      50,
      step = 1,
      post = "%"
    ),
    sliderInput(
      "sensitivity",
      "Sensitivity",
      0,
      100,
      50,
      step = 1,
      post = "%"
    ),
    sliderInput("preTestProbability", "Pre-test probability", 0, 100, 5, post =
                  "%")
  ),
  
  hr(),
  
  tabsetPanel(
    tabPanel(
      "Evidence Strength Plot",
      plotOutput("evidenceStrengthPlot", height = "600px")
    ),
    tabPanel("Network Flow",
             plotOutput("flowPlot", height = "600px")),
    tabPanel(
      "Network Mosaic",
      plotOutput("flowMosaic", height="600px")
    ),
    tabPanel(
      "Statistics",
      tableOutput("statistics")
    )
  )
  
  
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  # Initialise ggplot
  theme_set(theme_minimal())
  theme_update(
    axis.line.x = element_line(size=1, colour="black"),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.x = element_blank()
  )
  
  palette <- c("#A41623", "#ADE25D")
  
  
  networkFlow <- reactive({
    generate_network_flow(input$preTestProbability / 100,
                          input$sensitivity / 100,
                          input$specificity / 100)
  })
  
  networkPlotData <- reactive({
    flow <- networkFlow()
    data.frame(
      Truth = factor(
        c(TRUE, TRUE, FALSE, FALSE),
        levels = c(FALSE, TRUE),
        labels = c("Did not have major trauma", "Had major trauma")
      ),
      Prediction = factor(
        c(TRUE, FALSE, TRUE, FALSE),
        levels = c(FALSE, TRUE),
        labels = c("Triage tool negative", "Triage tool positive")
      ),
      Accuracy = factor(c(TRUE,FALSE,FALSE,TRUE),levels=c(FALSE,TRUE),labels=c("Inaccurate", "Accurate")),
      N = c(flow$tp, flow$fn, flow$fp, flow$tn)
    )
  })
  
  
  
  output$evidenceStrengthPlot <- renderPlot({
    evidence_strength_plot(input$sensitivity / 100, input$specificity / 100) + coord_fixed()
  })
  
  output$flowPlot <- renderPlot({
    ggplot(networkPlotData(), aes(x = Prediction, y = N, fill = Accuracy)) +
      geom_col(position="dodge") +
      scale_y_continuous(expand = expansion()) +
      labs(x=NULL) +
      facet_wrap(vars(Truth)) +
      scale_fill_discrete(guide = guide_legend(title=NULL), type=palette)
  }, res = 100)
  
  output$flowMosaic <- renderPlot({
    flow <- networkFlow()
    truth_positive_n <- flow$tp + flow$fn
    truth_negative_n <- flow$tn + flow$fp
    mosaic_data <- data.frame(
      xmin = c(0, 0, truth_positive_n, truth_positive_n),
      xmax = c(truth_positive_n, truth_positive_n, truth_positive_n + truth_negative_n, truth_positive_n + truth_negative_n),
      ymin = c(0, flow$tp/truth_positive_n, 0, flow$tn/truth_negative_n),
      ymax = c(flow$tp/truth_positive_n, 1, flow$tn/truth_negative_n, 1),
      accurate = factor(c(TRUE,FALSE,TRUE,FALSE),levels=c(FALSE,TRUE),labels=c("Inaccurate","Accurate")),
      text = c(flow$tp, flow$fn, flow$tn, flow$fp)
    )
    ggplot(mosaic_data, aes(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,fill=accurate,text=text)) +
      geom_rect(colour="white") +
      scale_y_continuous(expand = expansion(), labels=scales::percent) +
      scale_x_continuous(breaks=c(0,truth_positive_n), labels=c("Had major trauma", "Did not have major trauma"),expand=expansion()) +
      geom_text(aes(label=text, x = (xmin+xmax)/2, y = (ymin+ymax)/2),colour="white", size=10) +
      theme(
        axis.text.x = element_text(hjust = 0)
      ) +
      scale_fill_discrete(guide = guide_legend(title=NULL), type=palette) +
      labs(x=NULL,y=NULL)
  })
  
  output$statistics <- renderTable({
    
    flow <- networkFlow()
    stats <- list(
      Accuracy = (flow$tp+flow$tn)/(flow$tp+flow$tn+flow$fp+flow$fn)
    )
    
    return(
      data.frame(
        Statistic = names(stats),
        Value = stats
      )
    )
    
  })
  
}

# Run the application
shinyApp(ui = ui, server = server)