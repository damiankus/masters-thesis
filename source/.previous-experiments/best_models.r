# ==============================================
# SAME SEASON
# ==============================================



# mlp_5_5_th_0.5
# svr_gam0.000977_eps0.25_c4    
# winter
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp2_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp3_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp4_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp5_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 svr_gam0.000977_eps0.25_c4 = svr_factory(kernel = 'radial', gamma = 0.000977, epsilon = 0.25, cost = 4))


# mlp_4_3_th_0.7
# svr_gam0.000977_eps0.25_c0.25  
# spring
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_4_3_th_0.7 = mlp_factory(c(4, 3), threshold = 0.7),
                 mlp2_4_3_th_0.7 = mlp_factory(c(4, 3), threshold = 0.7),
                 mlp3_4_3_th_0.7 = mlp_factory(c(4, 3), threshold = 0.7),
                 mlp4_4_3_th_0.7 = mlp_factory(c(4, 3), threshold = 0.7),
                 mlp5_4_3_th_0.7 = mlp_factory(c(4, 3), threshold = 0.7),
                 svr_gam0.000977_eps0.25_c0.25 = svr_factory(kernel = 'radial', gamma = 0.000977, epsilon = 0.25, cost = 0.25))


# mlp_5_5_th_0.7 
# svr_gam0.000244_eps0.5_c0.25
# summer
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_5_5_th_0.7 = mlp_factory(c(5, 5), threshold = 0.7),
                 mlp2_5_5_th_0.7 = mlp_factory(c(5, 5), threshold = 0.7),
                 mlp3_5_5_th_0.7 = mlp_factory(c(5, 5), threshold = 0.7),
                 mlp4_5_5_th_0.7 = mlp_factory(c(5, 5), threshold = 0.7),
                 mlp5_5_5_th_0.7 = mlp_factory(c(5, 5), threshold = 0.7),
                 svr_gam0.000244_eps0.5_c0.25 = svr_factory(kernel = 'radial', gamma = 0.000244, epsilon = 0.5, cost = 0.25))


# mlp_3_2_th_0.3
# svr_gam0.000244_eps0.5_c16      
# autumn
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_3_2_th_0.3 = mlp_factory(c(3, 2), threshold = 0.3),
                 mlp2_3_2_th_0.3 = mlp_factory(c(3, 2), threshold = 0.3),
                 mlp3_3_2_th_0.3 = mlp_factory(c(3, 2), threshold = 0.3),
                 mlp4_3_2_th_0.3 = mlp_factory(c(3, 2), threshold = 0.3),
                 mlp5_3_2_th_0.3 = mlp_factory(c(3, 2), threshold = 0.3),
                 svr_gam0.000244_eps0.5_c16 = svr_factory(kernel = 'radial', gamma = 0.000244, epsilon = 0.5, cost = 16))



# ==============================================
# CONTINUOUS
# ==============================================



# mlp_5_th_0.7
# svr_gam0.000244_eps0.5_c1       
# winter
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_5_th_0.7 = mlp_factory(c(5), threshold = 0.7),
                 mlp2_5_th_0.7 = mlp_factory(c(5), threshold = 0.7),
                 mlp3_5_th_0.7 = mlp_factory(c(5), threshold = 0.7),
                 mlp4_5_th_0.7 = mlp_factory(c(5), threshold = 0.7),
                 mlp5_5_th_0.7 = mlp_factory(c(5), threshold = 0.7),
                 svr_gam0.000244_eps0.5_c1 = svr_factory(kernel = 'radial', gamma = 0.000244, epsilon = 0.5, cost = 1))


# mlp_6_5th_0.7  
# svr_gam0.000977_eps2_c1         
# spring
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_6_5_th_9.7 = mlp_factory(c(6, 5), threshold = 0.7),
                 mlp2_6_5_th_0.7 = mlp_factory(c(6, 5), threshold = 0.7),
                 mlp3_6_5_th_0.7 = mlp_factory(c(6, 5), threshold = 0.7),
                 mlp4_6_5_th_0.7 = mlp_factory(c(6, 5), threshold = 0.7),
                 mlp4_3_5_th_0.7 = mlp_factory(c(6, 5), threshold = 0.7),
                 svr_gam0.000977_eps2_c1 = svr_factory(kernel = 'radial', gamma = 0.000977, epsilon = 2, cost = 1))


# mlp_4_2_th_0.5 
# svr_gam0.00391_eps0.0312_c0.25  
# summer
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_4_2_th_0.5 = mlp_factory(c(4, 2), threshold = 0.5),
                 mlp2_4_2_th_0.5 = mlp_factory(c(4, 2), threshold = 0.5),
                 mlp3_4_2_th_0.5 = mlp_factory(c(4, 2), threshold = 0.5),
                 mlp4_4_2_th_0.5 = mlp_factory(c(4, 2), threshold = 0.5),
                 mlp5_4_2_th_0.5 = mlp_factory(c(4, 2), threshold = 0.5),
                 svr_gam0.00391_eps0.0312_c0.25 = svr_factory(kernel = 'radial', gamma = 0.00391, epsilon = 0.0312, cost = 0.25))


# mlp_5_5_th_0.5 
# svr_gam0.000244_eps0.5_c4      
# autumn
pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr,
                 mlp1_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp2_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp3_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp4_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 mlp5_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
                 svr_gam0.000244_eps0.5_c4 = svr_factory(kernel = 'radial', gamma = 0.000244, epsilon = 0.5, cost = 4))

